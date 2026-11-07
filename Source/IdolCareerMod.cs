using System;
using System.Collections.Generic;
using System.Reflection;
using Sims3.Gameplay.Abstracts;
using Sims3.Gameplay.Actors;
using Sims3.Gameplay.ActorSystems;
using Sims3.Gameplay.Autonomy;
using Sims3.Gameplay.Careers;
using Sims3.Gameplay.CAS;
using Sims3.Gameplay.CelebritySystem;
using Sims3.Gameplay.Core;
using Sims3.Gameplay.DreamsAndPromises;
using Sims3.Gameplay.EventSystem;
using Sims3.Gameplay.Interactions;
using Sims3.Gameplay.Objects.RabbitHoles;
using Sims3.Gameplay.Objects.Vehicles;
using Sims3.Gameplay.Opportunities;
using Sims3.Gameplay.Skills;
using Sims3.Gameplay.Situations;
using Sims3.Gameplay.Socializing;
using Sims3.Gameplay.Utilities;
using Sims3.SimIFace;
using Sims3.SimIFace.CAS;
using Sims3.SimIFace.CustomContent;
using Sims3.UI;
using Sims3.UI.Controller;
using Sims3.UI.Hud;

[assembly: Tunable]

namespace Sims3.Gameplay.Careers
{
    /// <summary>
    /// Bootstraps the custom Japanese Idol Career mod on game pre-load and world load.
    /// Registers custom OccupationNames, CareerEventType, and OpportunityNames values into
    /// ParserFunctions' EnumParser lookup tables, parses IdolCareerData / IdolCareerEvents /
    /// IdolOpportunities XML resources, attaches the Idol Career to Theatre and MovieSet
    /// rabbit holes, and injects custom Live Concert and Handshake & Cheki Meet-and-Greet
    /// interactions onto all ShowVenue rabbit holes.
    /// </summary>
    public static class IdolCareerMod
    {
        [Tunable]
        private static bool kInstantiator = false;

        private static bool sEnumsRegistered = false;
        private static bool sCareerParsed = false;
        private static bool sOpportunitiesParsed = false;
        private static EventListener sBoughtObjectListener = null;

        public const ulong kIdolCareerGuid = 0x26D1F7CA6C87D06DUL; // ResourceUtils.HashString64("IdolCareer")
        public const ulong kIdolCareerDataXmlInstance = 0x51CA3AE6850062C5UL; // ResourceUtils.HashString64("IdolCareerData")
        public const ulong kIdolCareerEventsXmlInstance = 0x441CBFD49D6384E6UL; // ResourceUtils.HashString64("IdolCareerEvents")
        public const ulong kIdolOpportunitiesXmlInstance = 0x401966CEF98A15C2UL; // ResourceUtils.HashString64("IdolOpportunities")

        // Custom Lifetime Wishes (Major Dreams) for Level 10 Solo Idol & Level 10 Idol Group
        public const uint kSoloIdolLtwPrimitiveId = 0x8E51A101U;  // Gameplay/Dreams/8e51a101:*
        public const uint kSoloIdolLtwInstanceId = 0x8E51B101U;
        public const uint kGroupIdolLtwPrimitiveId = 0x8E51A102U; // Gameplay/Dreams/8e51a102:*
        public const uint kGroupIdolLtwInstanceId = 0x8E51B102U;
        public const ulong kCasFeederTree0Id = 0x0520CB751BD4AF93UL;

        private static readonly string[] kCustomEventNames = new string[]
        {
            "IdolEvent_VoiceCrack",
            "IdolEvent_ViralFancam",
            "IdolEvent_TabloidPaparazzi",
            "IdolEvent_CenterDispute",
            "IdolEvent_AcousticEncore",
            "IdolEvent_HandshakeMarathon",
            "IdolEvent_BSideChartTopper",
            "IdolEvent_LuxurySponsorGift",
            "IdolEvent_AnimeThemeTieIn",
            "IdolEvent_SynchronizedFormation"
        };

        private static readonly string[] kCustomOpportunityNames = new string[]
        {
            "IdolOpp_LateNightFlyerBlitz",
            "IdolOpp_ConvenienceStoreCampaign",
            "IdolOpp_StaminaBootcamp",
            "IdolOpp_AnisongThemeTieIn",
            "IdolOpp_VarietyReactionQueen",
            "IdolOpp_CenterPositionAudition",
            "IdolOpp_GoldenWeekHandshake",
            "IdolOpp_CountdownDomeFestival"
        };

        static IdolCareerMod()
        {
            World.OnStartupAppEventHandler += new EventHandler(OnPreLoad);
            World.OnWorldLoadStartedEventHandler += new EventHandler(OnPreLoad);
            World.OnFinishedLoadingWorldFileEventHandler += new EventHandler(OnWorldFileLoaded);
            World.OnWorldLoadFinishedEventHandler += new EventHandler(OnWorldLoadFinished);
        }

        private static void OnPreLoad(object sender, EventArgs e)
        {
            try
            {
                EnsureEnumsRegistered();
                EnsureCareerAndLocationsRegistered();
            }
            catch (Exception)
            {
            }
        }

        private static void OnWorldFileLoaded(object sender, EventArgs e)
        {
            try
            {
                EnsureCareerAndLocationsRegistered();
            }
            catch (Exception)
            {
            }
        }

        private static void OnWorldLoadFinished(object sender, EventArgs e)
        {
            try
            {
                EnsureCareerAndLocationsRegistered();
                RegisterVenueInteractionsOnExistingObjects();

                if (sBoughtObjectListener == null)
                {
                    sBoughtObjectListener = EventTracker.AddListener(EventTypeId.kBoughtObject, new ProcessEventDelegate(OnObjectBought));
                }
            }
            catch (Exception)
            {
            }
        }

        private static ListenerAction OnObjectBought(Event e)
        {
            try
            {
                RabbitHole rh = e.TargetObject as RabbitHole;
                if (rh != null)
                {
                    AttachCareerToRabbitHole(rh);
                }
                ShowVenue venue = e.TargetObject as ShowVenue;
                if (venue != null)
                {
                    AddInteractionsToVenue(venue);
                }
            }
            catch (Exception)
            {
            }
            return ListenerAction.Keep;
        }

        public static void EnsureEnumsRegistered()
        {
            if (sEnumsRegistered)
            {
                return;
            }

            // Force ParserFunctions to initialize EnumParser dictionaries for our three enum types
            OccupationNames dummyOcc;
            ParserFunctions.TryParseEnum<OccupationNames>("Undefined", out dummyOcc, OccupationNames.Undefined, false);
            ParserFunctions.TryParseEnum<OccupationNames>("Undefined", out dummyOcc, OccupationNames.Undefined, true);

            Career.CareerEventType dummyEvt;
            ParserFunctions.TryParseEnum<Career.CareerEventType>("None", out dummyEvt, Career.CareerEventType.None, false);
            ParserFunctions.TryParseEnum<Career.CareerEventType>("None", out dummyEvt, Career.CareerEventType.None, true);

            OpportunityNames dummyOpp;
            ParserFunctions.TryParseEnum<OpportunityNames>("Undefined", out dummyOpp, OpportunityNames.Undefined, false);
            ParserFunctions.TryParseEnum<OpportunityNames>("Undefined", out dummyOpp, OpportunityNames.Undefined, true);

            RegisterCustomEnumValue<OccupationNames>("IdolCareer", (OccupationNames)kIdolCareerGuid);

            for (int i = 0; i < kCustomEventNames.Length; i++)
            {
                string evtName = kCustomEventNames[i];
                ulong hash = ResourceUtils.HashString64(evtName);
                RegisterCustomEnumValue<Career.CareerEventType>(evtName, (Career.CareerEventType)hash);
            }

            for (int i = 0; i < kCustomOpportunityNames.Length; i++)
            {
                string oppName = kCustomOpportunityNames[i];
                ulong hash = ResourceUtils.HashString64(oppName);
                RegisterCustomEnumValue<OpportunityNames>(oppName, (OpportunityNames)hash);
            }

            sEnumsRegistered = true;
        }

        private static void RegisterCustomEnumValue<T>(string name, T enumValue)
        {
            try
            {
                FieldInfo csField = typeof(ParserFunctions).GetField("sCaseSensitiveEnumParsers", BindingFlags.Static | BindingFlags.NonPublic);
                FieldInfo ciField = typeof(ParserFunctions).GetField("sCaseInsensitiveEnumParsers", BindingFlags.Static | BindingFlags.NonPublic);
                FieldInfo lookupField = typeof(EnumParser).GetField("mLookup", BindingFlags.Instance | BindingFlags.NonPublic);

                if (csField != null && lookupField != null)
                {
                    Dictionary<Type, EnumParser> csDict = csField.GetValue(null) as Dictionary<Type, EnumParser>;
                    if (csDict != null)
                    {
                        EnumParser parser;
                        if (csDict.TryGetValue(typeof(T), out parser) && parser != null)
                        {
                            Dictionary<string, object> lookup = lookupField.GetValue(parser) as Dictionary<string, object>;
                            if (lookup != null)
                            {
                                lookup[name] = enumValue;
                            }
                        }
                    }
                }

                if (ciField != null && lookupField != null)
                {
                    Dictionary<Type, EnumParser> ciDict = ciField.GetValue(null) as Dictionary<Type, EnumParser>;
                    if (ciDict != null)
                    {
                        EnumParser parser;
                        if (ciDict.TryGetValue(typeof(T), out parser) && parser != null)
                        {
                            Dictionary<string, object> lookup = lookupField.GetValue(parser) as Dictionary<string, object>;
                            if (lookup != null)
                            {
                                lookup[name.ToLowerInvariant()] = enumValue;
                            }
                        }
                    }
                }
            }
            catch (Exception)
            {
            }
        }

        public static void EnsureCareerAndLocationsRegistered()
        {
            EnsureEnumsRegistered();

            Occupation staticCareer = CareerManager.GetStaticOccupation((OccupationNames)kIdolCareerGuid);
            if (staticCareer == null || !sCareerParsed)
            {
                XmlDbData careerData = XmlDbData.ReadData(new ResourceKey(kIdolCareerDataXmlInstance, 0x0333406CU, 0U), false);
                if (careerData == null)
                {
                    careerData = XmlDbData.ReadData("IdolCareerData");
                }

                XmlDbData eventData = XmlDbData.ReadData(new ResourceKey(kIdolCareerEventsXmlInstance, 0x0333406CU, 0U), false);
                if (eventData == null)
                {
                    eventData = XmlDbData.ReadData("IdolCareerEvents");
                }

                if (careerData != null && eventData != null)
                {
                    Career.ParseCareerData(careerData, eventData);
                    sCareerParsed = true;
                }
            }

            EnsureLifetimeWishesRegistered();

            if (!sOpportunitiesParsed)
            {
                try
                {
                    XmlDbData oppData = XmlDbData.ReadData(new ResourceKey(kIdolOpportunitiesXmlInstance, 0x0333406CU, 0U), false);
                    if (oppData == null)
                    {
                        oppData = XmlDbData.ReadData("IdolOpportunities");
                    }

                    if (oppData != null)
                    {
                        MethodInfo parseOppMethod = typeof(OpportunityManager).GetMethod("ParseOpportunityData", BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic);
                        if (parseOppMethod != null)
                        {
                            parseOppMethod.Invoke(null, new object[] { oppData });
                            sOpportunitiesParsed = true;
                        }
                    }
                }
                catch (Exception)
                {
                }
            }

            Career idolCareer = CareerManager.GetStaticCareer((OccupationNames)kIdolCareerGuid);
            if (idolCareer != null)
            {
                try
                {
                    Theatre[] theatres = Queries.GetObjects<Theatre>();
                    if (theatres != null)
                    {
                        for (int i = 0; i < theatres.Length; i++)
                        {
                            AttachCareerToRabbitHole(theatres[i]);
                        }
                    }

                    MovieSet[] movieSets = Queries.GetObjects<MovieSet>();
                    if (movieSets != null)
                    {
                        for (int i = 0; i < movieSets.Length; i++)
                        {
                            AttachCareerToRabbitHole(movieSets[i]);
                        }
                    }
                }
                catch (Exception)
                {
                }
            }
        }

        private static void AttachCareerToRabbitHole(RabbitHole rh)
        {
            if (rh == null)
            {
                return;
            }
            if (!(rh is Theatre) && !(rh is MovieSet))
            {
                return;
            }

            Career idolCareer = CareerManager.GetStaticCareer((OccupationNames)kIdolCareerGuid);
            if (idolCareer == null || rh.CareerLocations == null)
            {
                return;
            }

            if (!rh.CareerLocations.ContainsKey(kIdolCareerGuid))
            {
                CareerLocation location = new CareerLocation(rh, idolCareer);
                rh.CareerLocations.Add(kIdolCareerGuid, location);
            }
        }

        public static void EnsureLifetimeWishesRegistered()
        {
            try
            {
                if (DreamsAndPromisesManager.sNodePrimitves == null || DreamsAndPromisesManager.sMajorWishes == null)
                {
                    return;
                }

                // 1. Solo Idol Level 10 Lifetime Wish ("Living Legend")
                List<DreamNodeInstance.TraitInfo> soloTraits = new List<DreamNodeInstance.TraitInfo>();
                AddTraitInfo(soloTraits, TraitNames.Virtuoso, false);
                AddTraitInfo(soloTraits, TraitNames.Charismatic, false);
                AddTraitInfo(soloTraits, TraitNames.NaturalPerformer, false); // Star Quality (EP3)
                AddTraitInfo(soloTraits, TraitNames.Ambitious, false);
                AddTraitInfo(soloTraits, TraitNames.Athletic, false);
                AddTraitInfo(soloTraits, TraitNames.NaturalBornPerformer, false);
                AddTraitInfo(soloTraits, TraitNames.Dramatic, false);
                AddTraitInfo(soloTraits, TraitNames.Diva, false);
                AddTraitInfo(soloTraits, TraitNames.Shy, true);
                AddTraitInfo(soloTraits, TraitNames.Loner, true);

                RegisterBranchLifetimeWish(
                    kSoloIdolLtwPrimitiveId,
                    kSoloIdolLtwInstanceId,
                    "Level10OfIdolSoloBranch",
                    "w_lifetime_idol_solo",
                    new DreamsAndPromisesFeedbackFunctionDelegate(SoloIdolLtwFeedbackFunction),
                    new DreamsAndPromisesCheckFunctionDelegate(SoloIdolLtwCheckFunction),
                    soloTraits);

                // 2. Idol Group Level 10 Lifetime Wish ("National Treasure")
                List<DreamNodeInstance.TraitInfo> groupTraits = new List<DreamNodeInstance.TraitInfo>();
                AddTraitInfo(groupTraits, TraitNames.Charismatic, false);
                AddTraitInfo(groupTraits, TraitNames.Friendly, false);
                AddTraitInfo(groupTraits, TraitNames.PartyAnimal, false);
                AddTraitInfo(groupTraits, TraitNames.Schmoozer, false);
                AddTraitInfo(groupTraits, TraitNames.NaturalPerformer, false); // Star Quality (EP3)
                AddTraitInfo(groupTraits, TraitNames.SocialButterfly, false);
                AddTraitInfo(groupTraits, TraitNames.Virtuoso, false);
                AddTraitInfo(groupTraits, TraitNames.Athletic, false);
                AddTraitInfo(groupTraits, TraitNames.Loner, true);
                AddTraitInfo(groupTraits, TraitNames.Evil, true);

                RegisterBranchLifetimeWish(
                    kGroupIdolLtwPrimitiveId,
                    kGroupIdolLtwInstanceId,
                    "Level10OfIdolGroupBranch",
                    "w_lifetime_idol_group",
                    new DreamsAndPromisesFeedbackFunctionDelegate(GroupIdolLtwFeedbackFunction),
                    new DreamsAndPromisesCheckFunctionDelegate(GroupIdolLtwCheckFunction),
                    groupTraits);
            }
            catch (Exception)
            {
            }
        }

        private static void AddTraitInfo(List<DreamNodeInstance.TraitInfo> list, TraitNames trait, bool excluded)
        {
            DreamNodeInstance.TraitInfo info = new DreamNodeInstance.TraitInfo();
            info.Trait = trait;
            info.Required = false;
            info.Excluded = excluded;
            list.Add(info);
        }

        private static void RegisterBranchLifetimeWish(
            uint primitiveId,
            uint instanceId,
            string primitiveName,
            string primaryIcon,
            DreamsAndPromisesFeedbackFunctionDelegate feedbackDelegate,
            DreamsAndPromisesCheckFunctionDelegate checkDelegate,
            List<DreamNodeInstance.TraitInfo> traits)
        {
            DreamNodePrimitive primitive = new DreamNodePrimitive(
                primitiveId,
                EventTypeId.kEventCareerPromotion,
                DreamNodePrimitive.InputSubjectType.Career,
                true,
                feedbackDelegate,
                checkDelegate,
                null,
                null,
                primitiveName,
                "Careers",
                primaryIcon,
                "",
                false,
                false,
                false,
                CASAGSAvailabilityFlags.HumanTeen | CASAGSAvailabilityFlags.HumanYoungAdult | CASAGSAvailabilityFlags.HumanAdult | CASAGSAvailabilityFlags.HumanElder,
                ProductVersion.BaseGame,
                0.0,
                "");

            DreamsAndPromisesManager.sNodePrimitves[primitiveId] = primitive;

            DreamNodeInstance.ConstructorData cd = new DreamNodeInstance.ConstructorData();
            cd.id = instanceId;
            cd.primitiveId = primitiveId;
            cd.ownerTree = kCasFeederTree0Id;
            cd.repeatable = false;
            cd.visible = true;
            cd.promiseLink = false;
            cd.zeroCheckExclusionFlags = DreamNodeInstance.ZeroCheckExclusionFlags.Traits;
            cd.ageFlags = CASAgeGenderFlags.Teen | CASAgeGenderFlags.YoungAdult | CASAgeGenderFlags.Adult | CASAgeGenderFlags.Elder;
            cd.traits = traits;
            cd.minTraitsReqired = 1U;
            cd.inheritSkill = false;
            cd.skills = new List<SkillNames>();
            cd.minSkill = 0;
            cd.maxSkill = 0;
            cd.inheritCareer = false;
            cd.careers = new List<OccupationNames>();
            cd.minCareer = 0;
            cd.maxCareer = 0;
            cd.ageWeight = 0f;
            cd.traitsWeight = 0f;
            cd.relationshipWeight = 0f;
            cd.moodWeight = 0f;
            cd.careersWeight = 0f;
            cd.skillsWeight = 0f;
            cd.moodFlavors = new List<MoodFlavor>();
            cd.minMood = 0;
            cd.maxMood = 0;
            cd.relationships = new List<LongTermRelationshipTypes>();
            cd.minRelationship = 0;
            cd.maxRelationship = 0;
            cd.displayTime = 0f;
            cd.satisfyTime = 0f;
            cd.repeatTime = 0f;
            cd.timeBetweenRepeats = 0f;
            cd.minAdvertisement = 0f;
            cd.maxAdvertisement = 1000000000f;
            cd.fulfillment = 30000f; // 30,000 Lifetime Happiness Points (matches Rock Star & Hit Movie Composer)
            cd.inheritsSubject = false;
            cd.inputSubject = "IdolCareer";
            cd.inputNumber = 10;
            cd.nextDreamSelectionProbability = 100f;
            cd.potentialStartNode = true;
            cd.localizationDescriptionKeyOverride = "";
            cd.localizationGenericNameKeyOverride = "";
            cd.localizationMaleNameKeyOverride = "";
            cd.localizationFemaleNameKeyOverride = "";

            DreamNodeInstance nodeInstance = new DreamNodeInstance(cd, false);

            // Ensure mInputSubject has the exact IdolCareer GUID even if constructed before EnumParser runs
            FieldInfo subjField = typeof(DreamNodeInstance).GetField("mInputSubject", BindingFlags.Instance | BindingFlags.NonPublic);
            if (subjField != null)
            {
                ActiveNodeBase.NodeSubject careerSubject = ActiveNodeBase.NodeSubject.Create(DreamNodePrimitive.InputSubjectType.Career, kIdolCareerGuid);
                subjField.SetValue(nodeInstance, careerSubject);
            }

            FieldInfo treesField = typeof(DreamsAndPromisesManager).GetField("sDreamTrees", BindingFlags.Static | BindingFlags.NonPublic);
            if (treesField != null)
            {
                Dictionary<ulong, DreamTree> trees = treesField.GetValue(null) as Dictionary<ulong, DreamTree>;
                DreamTree casTree;
                if (trees != null && trees.TryGetValue(kCasFeederTree0Id, out casTree) && casTree != null)
                {
                    if (casTree.GetNode(instanceId) == null)
                    {
                        casTree.AddNode(nodeInstance);
                        DreamNodeInstanceBase root = casTree.Root;
                        if (root != null)
                        {
                            root.AddChild(nodeInstance);
                            nodeInstance.SetParent(root.NodeId);
                        }
                        casTree.SetupStartTree();
                    }
                }
            }

            DreamsAndPromisesManager.sMajorWishes[primitiveId] = nodeInstance;
        }

        public static ActiveNodeBase.CheckResult SoloIdolLtwCheckFunction(ActiveDreamNode node)
        {
            return CheckIdolBranchLevel10(node, "SoloIdol");
        }

        public static FeedbackResult SoloIdolLtwFeedbackFunction(Event e, ActiveDreamNode node)
        {
            return FeedbackIdolBranchLevel10(node, "SoloIdol");
        }

        public static ActiveNodeBase.CheckResult GroupIdolLtwCheckFunction(ActiveDreamNode node)
        {
            return CheckIdolBranchLevel10(node, "IdolGroup");
        }

        public static FeedbackResult GroupIdolLtwFeedbackFunction(Event e, ActiveDreamNode node)
        {
            return FeedbackIdolBranchLevel10(node, "IdolGroup");
        }

        private static ActiveNodeBase.CheckResult CheckIdolBranchLevel10(ActiveDreamNode node, string branchName)
        {
            if (node != null && node.Owner != null && node.Owner.Occupation != null)
            {
                Occupation occ = node.Owner.Occupation;
                if (occ.Guid == (OccupationNames)kIdolCareerGuid && occ.Level >= 10 && occ.CurLevelBranchName == branchName)
                {
                    return ActiveNodeBase.CheckResult.kMajorDreamComplete;
                }
            }
            return ActiveNodeBase.CheckResult.kBecomeActive;
        }

        private static FeedbackResult FeedbackIdolBranchLevel10(ActiveDreamNode node, string branchName)
        {
            if (node != null && node.Owner != null && node.Owner.OccupationAsCareer != null)
            {
                Career career = node.Owner.OccupationAsCareer;
                if (career.Guid == (OccupationNames)kIdolCareerGuid && career.CurLevel != null && career.CurLevel.BranchName == branchName && career.CurLevel.Level >= 10)
                {
                    return new FeedbackResult(true);
                }
            }
            return new FeedbackResult(false);
        }

        private static void RegisterVenueInteractionsOnExistingObjects()
        {
            ShowVenue[] venues = Queries.GetObjects<ShowVenue>();
            if (venues != null)
            {
                for (int i = 0; i < venues.Length; i++)
                {
                    AddInteractionsToVenue(venues[i]);
                }
            }
        }

        private static void AddInteractionsToVenue(ShowVenue venue)
        {
            if (venue == null || venue.Interactions == null)
            {
                return;
            }

            bool hasConcert = false;
            bool hasMeetAndGreet = false;

            foreach (InteractionObjectPair pair in venue.Interactions)
            {
                if (pair.InteractionDefinition is IdolCareer.PerformIdolConcert.Definition)
                {
                    hasConcert = true;
                }
                else if (pair.InteractionDefinition is IdolCareer.HoldIdolMeetAndGreet.Definition)
                {
                    hasMeetAndGreet = true;
                }
            }

            if (!hasConcert)
            {
                venue.AddInteraction(IdolCareer.PerformIdolConcert.Singleton);
            }
            if (!hasMeetAndGreet)
            {
                venue.AddInteraction(IdolCareer.HoldIdolMeetAndGreet.Singleton);
            }
        }
    }

    /// <summary>
    /// Custom Japanese Idol Career for The Sims 3.
    /// Subclasses Music to inherit ConcertsPerformed serialization and MetricConcertsPerformed support,
    /// while adding SoloIdol and IdolGroup branches at Level 6, Late Night Celebrity Fame progression,
    /// custom work tones, unit chemistry bonuses, custom career vehicles, Live Concerts, and
    /// Handshake & Cheki Meet-and-Greet sessions.
    /// </summary>
    public class IdolCareer : Music
    {
        [TunableComment("Celebrity Fame points earned per work shift completed at Levels 1 through 10 (index 0 unused).")]
        [Tunable]
        public static uint[] kWorkShiftCelebrityPointsPerLevel = new uint[]
        {
            0U, 0U, 0U, 5U, 10U, 15U, 20U, 30U, 40U, 55U, 75U
        };

        [TunableComment("Bonus Celebrity Fame points awarded upon promotion to Levels 1 through 10 (index 0 unused).")]
        [Tunable]
        public static uint[] kPromotionCelebrityBonusPerLevel = new uint[]
        {
            0U, 0U, 0U, 15U, 35U, 75U, 150U, 250U, 400U, 600U, 900U
        };

        [TunableComment("Base concert payout at Level 6, scaling up to Level 10.")]
        [Tunable]
        public static int kBaseIdolConcertPay = 1200;

        [TunableComment("Additional concert payout per career level above 6.")]
        [Tunable]
        public static int kConcertPayPerLevelAboveSix = 950;

        [TunableComment("Base payout from CD & Cheki Polaroid bundle sales during a Handshake Meet-and-Greet.")]
        [Tunable]
        public static int kBaseMeetAndGreetPay = 650;

        [TunableComment("Additional Meet-and-Greet payout per career level above 5.")]
        [Tunable]
        public static int kMeetAndGreetPayPerLevelAboveFive = 450;

        public IdolCareer()
        {
        }

        public IdolCareer(XmlDbRow myRow, XmlDbTable levelTable, XmlDbTable eventDataTable)
            : base(myRow, levelTable, eventDataTable)
        {
            if (this.mCareerGuid == OccupationNames.Undefined)
            {
                this.mCareerGuid = (OccupationNames)IdolCareerMod.kIdolCareerGuid;
            }

            if (this.SharedData != null && this.SharedData.ToneDefinitions != null)
            {
                this.SharedData.ToneDefinitions.Add(new PracticeChoreographyTone.Definition("Gameplay/Excel/Careers/CareerList:PracticeChoreography"));
                this.SharedData.ToneDefinitions.Add(new PracticeFanServiceTone.Definition("Gameplay/Excel/Careers/CareerList:PracticeFanService"));
                this.SharedData.ToneDefinitions.Add(new RehearseLiveShowTone.Definition("Gameplay/Excel/Careers/CareerList:RehearseLiveShow"));
            }
        }

        public override bool OnLoadFixup(bool isQuitCareer)
        {
            IdolCareerMod.EnsureCareerAndLocationsRegistered();
            return base.OnLoadFixup(isQuitCareer);
        }

        protected override void SetLevel(CareerLevel level)
        {
            CareerLevel previousLevel = base.CurLevel;
            base.SetLevel(level);

            if (this.OwnerDescription != null)
            {
                // Ensure required skills are visible on the Sim's skill panel as they progress
                if (this.OwnerDescription.SkillManager != null)
                {
                    this.OwnerDescription.SkillManager.AddElement(SkillNames.Charisma);
                    this.OwnerDescription.SkillManager.AddElement(SkillNames.Athletic);
                }

                // Award promotion Celebrity Fame bonus when advancing to a higher level
                if (previousLevel != null && level != null && level.Level > previousLevel.Level)
                {
                    AwardPromotionCelebrityPoints(level.Level);
                }

                // Idol Group branch requires full unit roster (3 to 4 unit members)
                if (level != null && level.BranchName == "IdolGroup" && this.Coworkers != null)
                {
                    while (this.Coworkers.Count < 3)
                    {
                        if (!this.AddCoworker())
                        {
                            break;
                        }
                    }
                }
            }
        }

        public override void StartWorking()
        {
            if (this.OwnerDescription != null && this.OwnerDescription.SkillManager != null)
            {
                this.OwnerDescription.SkillManager.AddElement(SkillNames.Charisma);
                this.OwnerDescription.SkillManager.AddElement(SkillNames.Athletic);
            }
            base.StartWorking();
        }

        public override void FinishWorking()
        {
            AwardShiftCelebrityPoints();
            ApplyIdolGroupHarmonyBonus();
            base.FinishWorking();
        }

        private void AwardShiftCelebrityPoints()
        {
            if (this.OwnerDescription == null || this.OwnerDescription.CelebrityManager == null || base.CurLevel == null)
            {
                return;
            }

            int lvl = base.CurLevel.Level;
            if (lvl >= 1 && lvl < kWorkShiftCelebrityPointsPerLevel.Length)
            {
                uint points = kWorkShiftCelebrityPointsPerLevel[lvl];
                if (base.CurLevel.BranchName == "SoloIdol")
                {
                    // Solo Idols get a 20% personal spotlight Fame bonus
                    points = (uint)(points * 1.2f);
                }
                if (points > 0U)
                {
                    this.OwnerDescription.CelebrityManager.AddPoints(points);
                }
            }
        }

        private void AwardPromotionCelebrityPoints(int newLevel)
        {
            if (this.OwnerDescription == null || this.OwnerDescription.CelebrityManager == null)
            {
                return;
            }

            if (newLevel >= 1 && newLevel < kPromotionCelebrityBonusPerLevel.Length)
            {
                uint bonus = kPromotionCelebrityBonusPerLevel[newLevel];
                if (bonus > 0U)
                {
                    this.OwnerDescription.CelebrityManager.AddPoints(bonus);
                }
            }
        }

        private void ApplyIdolGroupHarmonyBonus()
        {
            if (base.CurLevel == null || base.CurLevel.BranchName != "IdolGroup")
            {
                return;
            }
            if (this.OwnerDescription == null || this.Coworkers == null || this.Coworkers.Count == 0)
            {
                return;
            }

            float totalLtr = 0f;
            int count = 0;
            foreach (SimDescription member in this.Coworkers)
            {
                if (member != null)
                {
                    Relationship rel = Relationship.Get(this.OwnerDescription, member, false);
                    if (rel != null && rel.LTR != null)
                    {
                        totalLtr += rel.LTR.Liking;
                        count++;
                    }
                }
            }

            if (count > 0)
            {
                float avgLtr = totalLtr / (float)count;
                Sim createdSim = this.OwnerDescription.CreatedSim;
                if (avgLtr >= 65f)
                {
                    this.AddPerformance(4.5f);
                    if (createdSim != null && createdSim.BuffManager != null)
                    {
                        createdSim.BuffManager.AddElement(BuffNames.Pumped, Origin.FromWork);
                    }
                }
            }
        }

        public override Car GetCareerCar()
        {
            if (base.CurLevel != null)
            {
                if (base.CurLevel.Level == 10)
                {
                    CarNpcManager.NpcCars limoType = (base.CurLevel.BranchName == "SoloIdol")
                        ? CarNpcManager.NpcCars.CarLimoPink
                        : CarNpcManager.NpcCars.CarLimoBlue;
                    CarNpcWithNpcDriver limo = CarNpcManager.Singleton.CreateNpcCarWithDriver(limoType);
                    if (limo != null)
                    {
                        return limo;
                    }
                }
                else if (base.CurLevel.BranchName == "IdolGroup" && base.CurLevel.Level >= 7)
                {
                    CarNpcWithNpcDriver tourVan = CarNpcManager.Singleton.CreateNpcCarWithDriver(CarNpcManager.NpcCars.CarVan4door);
                    if (tourVan != null)
                    {
                        return tourVan;
                    }
                }
            }
            return base.GetCareerCar();
        }

        public override bool CanGiveAutograph(AutographType autographType)
        {
            if (base.CurLevel == null)
            {
                return false;
            }
            if (autographType == AutographType.Individual)
            {
                return base.CurLevel.Level >= 6;
            }
            if (autographType == AutographType.ForAutographSession)
            {
                return base.CurLevel.Level >= 8;
            }
            return false;
        }

        public override bool ExportContent(ResKeyTable resKeyTable, ObjectIdTable objIdTable, IPropertyStreamWriter writer)
        {
            return base.ExportContent(resKeyTable, objIdTable, writer);
        }

        public override bool ImportContent(ResKeyTable resKeyTable, ObjectIdTable objIdTable, IPropertyStreamReader reader)
        {
            IdolCareerMod.EnsureCareerAndLocationsRegistered();
            return base.ImportContent(resKeyTable, objIdTable, reader);
        }

        // =====================================================================
        // CUSTOM WORK TONES
        // =====================================================================

        /// <summary>
        /// Custom work tone: "Drill Vocal & Dance Choreography"
        /// Builds Athletic skill and fitness at work while keeping the Idol energized.
        /// </summary>
        public class PracticeChoreographyTone : CareerTone
        {
            public class Definition : CareerToneDefinition
            {
                public Definition(string name)
                    : base(name)
                {
                }

                protected override CareerTone CreateToneOverride()
                {
                    return new PracticeChoreographyTone();
                }
            }

            public static float kAthleticSkillGainRate = 2.5f;

            public override bool Test(InteractionInstance ii, out StringDelegate reason)
            {
                reason = null;
                if (ii != null && ii.InstanceActor != null && ii.InstanceActor.BuffManager != null)
                {
                    if (ii.InstanceActor.BuffManager.HasElement(BuffNames.Fatigued))
                    {
                        return false;
                    }
                }
                return true;
            }

            protected override void BeginCareerTone(InteractionInstance interactionInstance)
            {
                if (this.Career != null && this.Career.OwnerDescription != null && this.Career.OwnerDescription.SkillManager != null)
                {
                    this.Career.OwnerDescription.SkillManager.AddElement(SkillNames.Athletic);
                    this.Career.OwnerDescription.SkillManager.StartSkillGain(SkillNames.Athletic, kAthleticSkillGainRate);
                }
            }

            protected override void EndCareerTone(InteractionInstance interactionInstance)
            {
                if (this.Career != null && this.Career.OwnerDescription != null && this.Career.OwnerDescription.SkillManager != null)
                {
                    this.Career.OwnerDescription.SkillManager.StopSkillGain(SkillNames.Athletic);
                }
            }

            public override void OnTimePassed(InteractionInstance interactionInstance, float totalTime, float deltaTime)
            {
            }
        }

        /// <summary>
        /// Custom work tone: "Practice Fan-Service & MC Appeal"
        /// Builds Charisma skill AND awards Late Night Celebrity Fame points while working.
        /// </summary>
        public class PracticeFanServiceTone : CareerTone
        {
            public class Definition : CareerToneDefinition
            {
                public Definition(string name)
                    : base(name)
                {
                }

                protected override CareerTone CreateToneOverride()
                {
                    return new PracticeFanServiceTone();
                }
            }

            public static float kCharismaSkillGainRate = 2.5f;
            public static float kCelebrityPointsPerSimMinute = 0.25f;
            private float mAccumulatedCelebrityPoints = 0f;

            public override bool Test(InteractionInstance ii, out StringDelegate reason)
            {
                reason = null;
                return true;
            }

            protected override void BeginCareerTone(InteractionInstance interactionInstance)
            {
                mAccumulatedCelebrityPoints = 0f;
                if (this.Career != null && this.Career.OwnerDescription != null && this.Career.OwnerDescription.SkillManager != null)
                {
                    this.Career.OwnerDescription.SkillManager.AddElement(SkillNames.Charisma);
                    this.Career.OwnerDescription.SkillManager.StartSkillGain(SkillNames.Charisma, kCharismaSkillGainRate);
                }
            }

            protected override void EndCareerTone(InteractionInstance interactionInstance)
            {
                if (this.Career != null && this.Career.OwnerDescription != null && this.Career.OwnerDescription.SkillManager != null)
                {
                    this.Career.OwnerDescription.SkillManager.StopSkillGain(SkillNames.Charisma);
                }
            }

            public override void OnTimePassed(InteractionInstance interactionInstance, float totalTime, float deltaTime)
            {
                if (interactionInstance != null && interactionInstance.InstanceActor != null && interactionInstance.InstanceActor.CelebrityManager != null)
                {
                    mAccumulatedCelebrityPoints += kCelebrityPointsPerSimMinute * deltaTime;
                    if (mAccumulatedCelebrityPoints >= 1f)
                    {
                        uint pts = (uint)mAccumulatedCelebrityPoints;
                        mAccumulatedCelebrityPoints -= (float)pts;
                        interactionInstance.InstanceActor.CelebrityManager.AddPoints(pts);
                    }
                }
            }
        }

        /// <summary>
        /// Custom work tone: "Rehearse Live Show Setlist"
        /// Available from Level 5+ in both SoloIdol and IdolGroup tracks. Fills the concert preparation
        /// progress bar and increments ConcertsPerformed when reaching 100%.
        /// </summary>
        public class RehearseLiveShowTone : Music.PerformTone
        {
            public new class Definition : CareerToneDefinition
            {
                public Definition(string name)
                    : base(name)
                {
                }

                protected override CareerTone CreateToneOverride()
                {
                    return new RehearseLiveShowTone();
                }
            }

            public override bool ShouldAddTone(Career career)
            {
                return career != null && career.CurLevel != null && career.CurLevel.Level >= 5;
            }
        }

        // =====================================================================
        // CUSTOM CAREER CHANCE CARD & OPPORTUNITY EVENT SUBCLASSES
        // =====================================================================

        public class EventIdolReward : Career.EventReward
        {
            public EventIdolReward()
            {
            }

            public EventIdolReward(XmlDbRow row, Dictionary<string, Dictionary<int, CareerLevel>> careerLevels, string tableName)
                : base(row, careerLevels, tableName)
            {
                if (this.mEventType == Career.CareerEventType.None)
                {
                    string evtName = row.GetString("EventType");
                    if (!string.IsNullOrEmpty(evtName))
                    {
                        this.mEventType = (Career.CareerEventType)ResourceUtils.HashString64(evtName);
                    }
                }
            }

            public override void RunEvent(Career c)
            {
                base.RunEvent(c);
                if (c != null && c.OwnerDescription != null && c.OwnerDescription.CelebrityManager != null)
                {
                    c.OwnerDescription.CelebrityManager.AddPoints(40U);
                }
            }
        }

        public class EventIdolChoice : Career.EventChoice
        {
            public EventIdolChoice()
            {
            }

            public EventIdolChoice(XmlDbRow row, Dictionary<string, Dictionary<int, CareerLevel>> careerLevels, string tableName)
                : base(row, careerLevels, tableName)
            {
                if (this.mEventType == Career.CareerEventType.None)
                {
                    string evtName = row.GetString("EventType");
                    if (!string.IsNullOrEmpty(evtName))
                    {
                        this.mEventType = (Career.CareerEventType)ResourceUtils.HashString64(evtName);
                    }
                }
            }

            protected override void GiveRewards(bool bWin, Sim sim, string resultDescription, Origin origin)
            {
                base.GiveRewards(bWin, sim, resultDescription, origin);
                if (bWin && sim != null && sim.CelebrityManager != null)
                {
                    sim.CelebrityManager.AddPoints(60U);
                }
            }
        }

        public class EventIdolOpportunity : Career.EventOpportunity
        {
            public EventIdolOpportunity()
            {
            }

            public EventIdolOpportunity(XmlDbRow row, Dictionary<string, Dictionary<int, CareerLevel>> careerLevels, string tableName)
                : base(row, careerLevels, tableName)
            {
                if (this.mEventType == Career.CareerEventType.None)
                {
                    string evtName = row.GetString("EventType");
                    if (!string.IsNullOrEmpty(evtName))
                    {
                        this.mEventType = (Career.CareerEventType)ResourceUtils.HashString64(evtName);
                    }
                }
                if (this.mOpportunity == OpportunityNames.Undefined)
                {
                    string oppName = row.GetString("OpportunityName");
                    if (!string.IsNullOrEmpty(oppName))
                    {
                        this.mOpportunity = (OpportunityNames)ResourceUtils.HashString64(oppName);
                    }
                }
            }
        }

        // =====================================================================
        // CUSTOM VENUE INTERACTIONS: LIVE CONCERT & HANDSHAKE MEET-AND-GREET
        // =====================================================================

        /// <summary>
        /// Allows Solo Idols and Idol Group members at Level 6–10 to perform a paid
        /// Idol Live Concert at any ShowVenue (Theatre, Stadium, MovieSet).
        /// Counts toward the ConcertsPerformed (Live Shows) metric, triggers venue concert
        /// audio/lights, awards Simoleons, and grants Celebrity Fame points.
        /// </summary>
        public sealed class PerformIdolConcert : RabbitHole.RabbitHoleInteraction<Sim, ShowVenue>
        {
            public sealed class Definition : InteractionDefinition<Sim, ShowVenue, PerformIdolConcert>
            {
                protected override string GetInteractionName(Sim actor, ShowVenue target, InteractionObjectPair iop)
                {
                    if (actor != null && actor.Occupation != null && actor.Occupation.CurLevelBranchName == "IdolGroup")
                    {
                        return Localization.LocalizeString(actor.IsFemale, "Gameplay/Excel/Careers/IdolCareer:PerformGroupLiveConcert", new object[0]);
                    }
                    return Localization.LocalizeString(actor != null && actor.IsFemale, "Gameplay/Excel/Careers/IdolCareer:PerformIdolLiveConcert", new object[0]);
                }

                protected override bool Test(Sim a, ShowVenue target, bool isAutonomous, ref GreyedOutTooltipCallback greyedOutTooltipCallback)
                {
                    if (isAutonomous || a == null || target == null)
                    {
                        return false;
                    }

                    IdolCareer idolCareer = a.Occupation as IdolCareer;
                    if (idolCareer == null || idolCareer.CurLevel == null || idolCareer.CurLevel.Level < 6)
                    {
                        return false;
                    }

                    float hour = SimClock.Hours24;
                    if (hour < 12f || hour >= 23f)
                    {
                        greyedOutTooltipCallback = delegate()
                        {
                            return Localization.LocalizeString(a.IsFemale, "Gameplay/Excel/Careers/IdolCareer:ConcertHoursTooltip", new object[] { a });
                        };
                        return false;
                    }

                    return true;
                }
            }

            public static readonly InteractionDefinition Singleton = new Definition();

            private static MethodInfo sStartConcertMethod;
            private static MethodInfo sEndConcertMethod;

            public override void ConfigureInteraction()
            {
                TimedStage stage = new TimedStage(this.GetInteractionName(), 180f, false, true, true);
                this.Stages = new List<Stage>(new Stage[] { stage });
            }

            protected override bool InRabbitHole()
            {
                base.BeginCommodityUpdates();

                InvokeVenueMethod(this.Target, "StartPlayerConcert", ref sStartConcertMethod);
                base.StartStages();

                bool succeeded = base.DoLoop(ExitReason.Default);

                InvokeVenueMethod(this.Target, "EndPlayerConcert", ref sEndConcertMethod);
                base.EndCommodityUpdates(succeeded);

                if (succeeded)
                {
                    EventTracker.SendEvent(EventTypeId.kPerformedConcert, this.Actor);

                    IdolCareer idol = this.Actor.Occupation as IdolCareer;
                    if (idol != null && idol.CurLevel != null)
                    {
                        idol.ConcertsPerformed++;

                        int level = idol.CurLevel.Level;
                        int charismaBonus = 0;
                        if (this.Actor.SkillManager != null)
                        {
                            int ch = this.Actor.SkillManager.GetSkillLevel(SkillNames.Charisma);
                            if (ch > 0)
                            {
                                charismaBonus = ch * 120;
                            }
                        }

                        int pay = kBaseIdolConcertPay + Math.Max(0, level - 6) * kConcertPayPerLevelAboveSix + charismaBonus;
                        if (this.Target is Stadium)
                        {
                            // Arena / Dome live concerts draw larger crowds and higher ticket revenue
                            pay = (int)(pay * 1.35f);
                        }

                        this.Actor.ModifyFunds(pay);

                        if (this.Actor.CelebrityManager != null)
                        {
                            uint fameEarned = (uint)(80 + Math.Max(0, level - 5) * 35);
                            this.Actor.CelebrityManager.AddPoints(fameEarned);
                        }

                        if (this.Actor.BuffManager != null)
                        {
                            this.Actor.BuffManager.AddElement(BuffNames.Pumped, Origin.FromWork);
                        }

                        string tnsKey = (idol.CurLevel.BranchName == "IdolGroup")
                            ? "Gameplay/Excel/Careers/IdolCareer:GroupConcertCompleteTNS"
                            : "Gameplay/Excel/Careers/IdolCareer:SoloConcertCompleteTNS";

                        string message = Localization.LocalizeString(this.Actor.IsFemale, tnsKey, new object[] { this.Actor, pay });
                        this.Actor.ShowTNSIfSelectable(message, StyledNotification.NotificationStyle.kGameMessagePositive, this.Target.ObjectId, this.Actor.ObjectId);
                    }
                }

                return succeeded;
            }

            private static void InvokeVenueMethod(ShowVenue venue, string methodName, ref MethodInfo cachedMethod)
            {
                try
                {
                    if (cachedMethod == null)
                    {
                        cachedMethod = typeof(ShowVenue).GetMethod(methodName, BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
                    }
                    if (cachedMethod != null && venue != null)
                    {
                        cachedMethod.Invoke(venue, null);
                    }
                }
                catch (Exception)
                {
                }
            }
        }

        /// <summary>
        /// Allows Idols at Level 5–10 to hold an authentic Japanese Idol Handshake & Cheki
        /// (Polaroid) Meet-and-Greet session at any ShowVenue (Theatre, Stadium, MovieSet).
        /// Generates CD/Cheki bundle sales income, builds Charisma skill, grants Celebrity
        /// Fame points, and boosts relationship with Idol Group unit members.
        /// </summary>
        public sealed class HoldIdolMeetAndGreet : RabbitHole.RabbitHoleInteraction<Sim, ShowVenue>
        {
            public sealed class Definition : InteractionDefinition<Sim, ShowVenue, HoldIdolMeetAndGreet>
            {
                protected override string GetInteractionName(Sim actor, ShowVenue target, InteractionObjectPair iop)
                {
                    return Localization.LocalizeString(actor != null && actor.IsFemale, "Gameplay/Excel/Careers/IdolCareer:HoldIdolMeetAndGreet", new object[0]);
                }

                protected override bool Test(Sim a, ShowVenue target, bool isAutonomous, ref GreyedOutTooltipCallback greyedOutTooltipCallback)
                {
                    if (isAutonomous || a == null || target == null)
                    {
                        return false;
                    }

                    IdolCareer idolCareer = a.Occupation as IdolCareer;
                    if (idolCareer == null || idolCareer.CurLevel == null || idolCareer.CurLevel.Level < 5)
                    {
                        return false;
                    }

                    float hour = SimClock.Hours24;
                    if (hour < 10f || hour >= 21f)
                    {
                        greyedOutTooltipCallback = delegate()
                        {
                            return Localization.LocalizeString(a.IsFemale, "Gameplay/Excel/Careers/IdolCareer:MeetAndGreetHoursTooltip", new object[] { a });
                        };
                        return false;
                    }

                    return true;
                }
            }

            public static readonly InteractionDefinition Singleton = new Definition();

            public override void ConfigureInteraction()
            {
                TimedStage stage = new TimedStage(this.GetInteractionName(), 120f, false, true, true);
                this.Stages = new List<Stage>(new Stage[] { stage });
            }

            protected override bool InRabbitHole()
            {
                base.BeginCommodityUpdates();

                if (this.Actor.SkillManager != null)
                {
                    this.Actor.SkillManager.AddElement(SkillNames.Charisma);
                    this.Actor.SkillManager.StartSkillGain(SkillNames.Charisma, 3.0f);
                }

                base.StartStages();
                bool succeeded = base.DoLoop(ExitReason.Default);

                if (this.Actor.SkillManager != null)
                {
                    this.Actor.SkillManager.StopSkillGain(SkillNames.Charisma);
                }

                base.EndCommodityUpdates(succeeded);

                if (succeeded)
                {
                    IdolCareer idol = this.Actor.Occupation as IdolCareer;
                    if (idol != null && idol.CurLevel != null)
                    {
                        int level = idol.CurLevel.Level;
                        int charismaLevel = (this.Actor.SkillManager != null)
                            ? Math.Max(0, this.Actor.SkillManager.GetSkillLevel(SkillNames.Charisma))
                            : 0;

                        int revenue = kBaseMeetAndGreetPay + Math.Max(0, level - 5) * kMeetAndGreetPayPerLevelAboveFive + (charismaLevel * 85);
                        this.Actor.ModifyFunds(revenue);

                        if (this.Actor.CelebrityManager != null)
                        {
                            uint fameEarned = (uint)(60 + Math.Max(0, level - 4) * 25);
                            this.Actor.CelebrityManager.AddPoints(fameEarned);
                        }

                        // Boost unit chemistry if in IdolGroup branch (or shared trainee levels)
                        if (idol.Coworkers != null && this.Actor.SimDescription != null)
                        {
                            foreach (SimDescription coworker in idol.Coworkers)
                            {
                                if (coworker != null)
                                {
                                    Relationship rel = Relationship.Get(this.Actor.SimDescription, coworker, true);
                                    if (rel != null && rel.LTR != null)
                                    {
                                        rel.LTR.UpdateLiking(8f);
                                    }
                                }
                            }
                        }

                        idol.AddPerformance(6f);

                        string message = Localization.LocalizeString(
                            this.Actor.IsFemale,
                            "Gameplay/Excel/Careers/IdolCareer:MeetAndGreetCompleteTNS",
                            new object[] { this.Actor, revenue });

                        this.Actor.ShowTNSIfSelectable(message, StyledNotification.NotificationStyle.kGameMessagePositive, this.Target.ObjectId, this.Actor.ObjectId);
                    }
                }

                return succeeded;
            }
        }
    }
}
