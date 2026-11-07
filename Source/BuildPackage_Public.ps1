<#
.SYNOPSIS
    Builds the TS3_IdolCareer_Mod.package file for The Sims 3.

.DESCRIPTION
    This script compiles all mod resources into a single .package file:
      - Compiled S3SA script assembly (IdolCareerMod.dll)
      - Career XML data, career events, and opportunity tuning files
      - Custom career and Lifetime Wish icons (_IMAG)
      - Localized STBL string tables for all 22 game locales
      - NameMap resource (_KEY)

.REQUIREMENTS
    - Windows PowerShell 5.1 or PowerShell 7+
    - S3PE (Sims 3 Package Editor) installed (default: "C:\Program Files\s3pe")
    - Compiled IdolCareerMod.dll (place in Source\ or specify via -DllPath)

.EXAMPLE
    .\BuildPackage_Public.ps1

.EXAMPLE
    .\BuildPackage_Public.ps1 -S3PEDir "D:\Tools\s3pe" -OutputPath "D:\Sims3Mods\TS3_IdolCareer_Mod.package"
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Path to the repository root directory.")]
    [string]$ProjectDir = "",

    [Parameter(HelpMessage = "Path to the S3PE installation directory containing s3pi DLLs.")]
    [string]$S3PEDir = "",

    [Parameter(HelpMessage = "Path to the precompiled IdolCareerMod.dll.")]
    [string]$DllPath = "",

    [Parameter(HelpMessage = "Output path for the resulting .package file.")]
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"

# ==============================================================================
# 1. RESOLVE & VALIDATE PATHS
# ==============================================================================
if (-not $ProjectDir) {
    $ProjectDir = (Resolve-Path "$PSScriptRoot\..").Path
} else {
    $ProjectDir = (Resolve-Path $ProjectDir).Path
}

Write-Host "Project Root : $ProjectDir" -ForegroundColor Cyan

# Locate S3PE directory
if (-not $S3PEDir) {
    $candidateS3PE = @("C:\Program Files\s3pe", "C:\Program Files (x86)\s3pe")
    if ($env:S3PE_HOME) { $candidateS3PE += $env:S3PE_HOME }

    foreach ($dir in $candidateS3PE) {
        if ($dir -and (Test-Path (Join-Path $dir "s3pi.Package.dll"))) {
            $S3PEDir = $dir
            break
        }
    }

    if (-not $S3PEDir) {
        throw "Could not locate S3PE installation. Please specify -S3PEDir '<path to s3pe>' (e.g. 'C:\Program Files\s3pe')."
    }
}
Write-Host "S3PE Directory: $S3PEDir" -ForegroundColor Cyan

# Locate compiled assembly DLL
if (-not $DllPath) {
    $candidateDlls = @(
        "$PSScriptRoot\IdolCareerMod.dll",
        "$ProjectDir\Source\IdolCareerMod.dll",
        "$ProjectDir\bin\Release\IdolCareerMod.dll",
        "$ProjectDir\bin\Debug\IdolCareerMod.dll"
    )

    foreach ($cand in $candidateDlls) {
        if ($cand -and (Test-Path $cand)) {
            $DllPath = (Resolve-Path $cand).Path
            break
        }
    }

    if (-not $DllPath) {
        throw "Could not locate IdolCareerMod.dll. Please compile the C# source or place IdolCareerMod.dll in the Source directory, or specify -DllPath '<path>'."
    }
}
Write-Host "Assembly DLL  : $DllPath" -ForegroundColor Cyan

# Set output package path
if (-not $OutputPath) {
    $OutputPath = Join-Path $ProjectDir "TS3_IdolCareer_Mod.package"
}
Write-Host "Output Package: $OutputPath" -ForegroundColor Cyan

# ==============================================================================
# 2. FNV-1 64-BIT HASHING (Native Sims 3 ResourceUtils.HashString64)
# ==============================================================================
# The Sims 3 uses standard 64-bit FNV-1 hashing on lowercased ASCII text.
# We define this in C# via Add-Type to eliminate any dependency on game DLLs.
if (-not ([System.Management.Automation.PSTypeName]'SimHashHelper').Type) {
    Add-Type -TypeDefinition @"
    using System;
    public static class SimHashHelper {
        public static ulong Hash64(string s) {
            if (string.IsNullOrEmpty(s)) return 0;
            ulong hash = 0xcbf29ce484222325UL;
            foreach (char c in s.ToLowerInvariant()) {
                hash = unchecked(hash * 0x00000100000001b3UL);
                hash = unchecked(hash ^ (byte)c);
            }
            return hash;
        }
    }
"@
}

function Get-SimHash64([string]$text) {
    return [SimHashHelper]::Hash64($text)
}

# ==============================================================================
# 3. LOAD S3PI ASSEMBLIES (S3PE)
# ==============================================================================
$requiredS3piDlls = @(
    "s3pi.Interfaces.dll",
    "s3pi.Package.dll",
    "s3pi.ScriptResource.dll",
    "s3pi.StblResource.dll",
    "s3pi.NameMapResource.dll"
)

foreach ($dll in $requiredS3piDlls) {
    $dllFile = Join-Path $S3PEDir $dll
    if (-not (Test-Path $dllFile)) {
        throw "Missing required S3PE library: $dllFile"
    }
    [System.Reflection.Assembly]::LoadFrom($dllFile) | Out-Null
}

function New-ResourceKey([uint32]$type, [uint32]$group, [uint64]$instance) {
    return New-Object s3pi.Interfaces.TGIBlock(0, $null, $type, $group, $instance)
}

# ==============================================================================
# 4. FULL LOCALIZED ENGLISH STRING TABLE (STBL)
# ==============================================================================
$strings = [ordered]@{
    # --------------------------------------------------------------------------
    # 1. CareerList & Work Tones (Gameplay/Excel/Careers/CareerList:*)
    # --------------------------------------------------------------------------
    "Gameplay/Careers/GetJobInRabbitHole:JoinCareer2797289292350083181" = "Join Idol Career"
    "Gameplay/Careers/GetJobInRabbitHole:JoinCareerIdolCareer" = "Join Idol Career"
    "Gameplay/Excel/Careers/CareerList:IdolCareer" = "Idol"
    "Gameplay/Excel/Careers/CareerList:IdolCareerDescription" = "Behind the glittering frills, synchronized glowsticks, and chart-topping hooks lies the most demanding proving ground in show business. Starting on rain-slicked street corners with a stack of hand-drawn flyers and a dream, aspiring Idols must master breathless dance choreography, effortless charisma, and relentless media scrutiny. Will you command the spotlight alone as a generational Solo Idol, or unite with your unit mates to conquer the national dome stage as an Idol Group?"
    "Gameplay/Excel/Careers/CareerList:IdolJobOffer" = "Starlight Production's talent scouts saw something unmistakable in {0.SimName}—that rare, electric spark that makes a crowd look twice. You'll start at the very bottom of the agency roster, handing out flyers in the rain and learning basic vocal scales in a cramped basement studio. Keep your smile radiant, build your stamina and charisma, and one day fifty thousand penlights will shine just for you!"
    "Gameplay/Excel/Careers/CareerList:IdolRetirement" = "After a legendary graduation concert that left not a dry eye in the arena, {0.SimName} has officially laid down the microphone on stage one last time. Though {0.SimName} is stepping back from daily rehearsals, the royalty checks, platinum plaques, and eternal devotion of the fandom will keep arriving for a lifetime."
    "Gameplay/Excel/Careers/CareerList:IdolBranchOffer" = "With your indie debut single climbing the charts and major record labels lining up outside the agency office, Producer-san has called {0.SimName} in for a career-defining decision. Would you like to debut as a Solo Idol—commanding every spotlight, anime theme tie-in, and solo arena tour on your own terms—or debut at the heart of a flagship Idol Group, where synchronized formations, unit chemistry, and the annual General Election determine the nation's ultimate Center?"
    "Gameplay/Excel/Careers/CareerList:SoloIdol" = "Solo Idol"
    "Gameplay/Excel/Careers/CareerList:IdolGroup" = "Idol Group"

    # Standard Work Tones
    "Gameplay/Excel/Careers/CareerList:IdolWorkHard" = "Go Full-Throttle"
    "Gameplay/Excel/Careers/CareerList:IdolWorkHardDescription" = "Push through burning calves and vocal fatigue to deliver 120% on every take, rehearsal run-through, and camera check."
    "Gameplay/Excel/Careers/CareerList:IdolTakeItEasy" = "Lip-Sync to Track"
    "Gameplay/Excel/Careers/CareerList:IdolTakeItEasyDescription" = "Save your voice and energy by letting the pre-recorded backing track and stage smoke do the heavy lifting today."
    "Gameplay/Excel/Careers/CareerList:MeetAgencyTrainees" = "Meet Fellow Agency Idols"
    "Gameplay/Excel/Careers/CareerList:MeetAgencyTraineesDescription" = "Introduce yourself to the other trainees and unit members sharing the dance studio and dressing rooms."
    "Gameplay/Excel/Careers/CareerList:BondInGreenRoom" = "Bond in Green Room"
    "Gameplay/Excel/Careers/CareerList:BondInGreenRoomDescription" = "Share konbini snacks, synchronize dance cues, and build unit chemistry with your fellow idols between rehearsals."
    "Gameplay/Excel/Careers/CareerList:PitchConceptToProducer" = "Consult with Chief Producer"
    "Gameplay/Excel/Careers/CareerList:PitchConceptToProducerDescription" = "Discuss single concepts, costume designs, and promotional schedules with the agency's executive producer."
    "Gameplay/Excel/Careers/CareerList:NapInDressingRoom" = "Nap Backstage"
    "Gameplay/Excel/Careers/CareerList:NapInDressingRoomDescription" = "Curl up on the dressing room sofa under a rack of sequined stage costumes for some desperately needed shut-eye."

    # Custom Idol Work Tones
    "Gameplay/Excel/Careers/CareerList:PracticeChoreography" = "Drill Choreography"
    "Gameplay/Excel/Careers/CareerList:PracticeChoreographyDescription" = "Run relentless high-BPM formation drills in front of the studio mirrors while singing full-chest chorus lines to build Athletic stamina."
    "Gameplay/Excel/Careers/CareerList:PracticeFanService" = "Practice Fan-Service"
    "Gameplay/Excel/Careers/CareerList:PracticeFanServiceDescription" = "Perfect your signature wink, MC banter, and kamera-mesen (finding the active camera lens in a split second) to boost Charisma and Celebrity Fame."
    "Gameplay/Excel/Careers/CareerList:RehearseLiveShow" = "Rehearse Live Show"
    "Gameplay/Excel/Careers/CareerList:RehearseLiveShowDescription" = "Run a full dress rehearsal with stage lighting, pyrotechnic cues, and costume quick-changes to prepare for upcoming Live Shows."

    # --------------------------------------------------------------------------
    # 2. Coworker & Custom Venue Interaction Strings (Gameplay/Excel/Careers/IdolCareer:*)
    # --------------------------------------------------------------------------
    "Gameplay/Excel/Careers/IdolCareer:UnitMate" = "Unit Member"
    "Gameplay/Excel/Careers/IdolCareer:UnitMate_Female" = "Unit Member"
    "Gameplay/Excel/Careers/IdolCareer:UnitChemistry" = "Unit Chemistry"
    "Gameplay/Excel/Careers/IdolCareer:UnitChemistry_Female" = "Unit Chemistry"
    "Gameplay/Excel/Careers/IdolCareer:UnitChemistryDesc" = "An idol unit lives and dies by the trust and synchronicity between its members. Keep your relationships with your unit mates high to nail complex stage formations and earn bonus performance!"
    "Gameplay/Excel/Careers/IdolCareer:UnitChemistryDesc_Female" = "An idol unit lives and dies by the trust and synchronicity between its members. Keep your relationships with your unit mates high to nail complex stage formations and earn bonus performance!"

    "Gameplay/Excel/Careers/IdolCareer:PerformIdolLiveConcert" = "Perform Idol Live Concert"
    "Gameplay/Excel/Careers/IdolCareer:PerformGroupLiveConcert" = "Perform Idol Group Live Concert"
    "Gameplay/Excel/Careers/IdolCareer:ConcertHoursTooltip" = "Idol Live Concerts can only be held between 12:00 PM and 11:00 PM when the stage crew and audience penlights are ready!"
    "Gameplay/Excel/Careers/IdolCareer:SoloConcertCompleteTNS" = "The venue erupted into a blinding sea of penlights and deafening wota chants as {0.SimName} delivered an unforgettable Solo Idol Live Concert! Between ticket sales and limited-edition tour goods, {0.SimName} earned §{1} and a surge of Celebrity Fame!"
    "Gameplay/Excel/Careers/IdolCareer:GroupConcertCompleteTNS" = "With razor-sharp formation transitions and a soaring three-encore finale, {0.SimName} and the unit brought the house down! {0.SimName}'s share of the box office and merchandise revenue totaled §{1}, along with a massive boost to Celebrity Fame!"
    "Gameplay/Excel/Careers/IdolCareer:HoldIdolMeetAndGreet" = "Hold Handshake & Cheki Meet-and-Greet"
    "Gameplay/Excel/Careers/IdolCareer:MeetAndGreetHoursTooltip" = "Handshake & Cheki Meet-and-Greet booths operate between 10:00 AM and 9:00 PM!"
    "Gameplay/Excel/Careers/IdolCareer:MeetAndGreetCompleteTNS" = "{0.SimName} greeted hundreds of devoted fans with warm handshakes, personalized Polaroid (cheki) poses, and effortless charm! CD bundle and cheki ticket sales brought in §{1}, while {0.SimName}'s Charisma, Fame, and career standing soared!"

    # --------------------------------------------------------------------------
    # 3. Level Titles (Levels 1-5 Shared, 6-10 SoloIdol, 6-10 IdolGroup)
    # --------------------------------------------------------------------------
    "Gameplay/Excel/Careers/IdolCareer:FlyerDistributor" = "Backstreet Flyer Distributor"
    "Gameplay/Excel/Careers/IdolCareer:FlyerDistributor_Female" = "Backstreet Flyer Distributor"
    "Gameplay/Excel/Careers/IdolCareer:Kenkyuusei" = "Backup Dancer"
    "Gameplay/Excel/Careers/IdolCareer:Kenkyuusei_Female" = "Backup Dancer"
    "Gameplay/Excel/Careers/IdolCareer:BackDancer" = "Underground Idol"
    "Gameplay/Excel/Careers/IdolCareer:BackDancer_Female" = "Underground Idol"
    "Gameplay/Excel/Careers/IdolCareer:LiveHouseIdol" = "Local Idol"
    "Gameplay/Excel/Careers/IdolCareer:LiveHouseIdol_Female" = "Local Idol"
    "Gameplay/Excel/Careers/IdolCareer:IndieDebutIdol" = "Indie Label Debut"
    "Gameplay/Excel/Careers/IdolCareer:IndieDebutIdol_Female" = "Indie Label Debut"

    # Solo Idol Branch Titles (Levels 6-10)
    "Gameplay/Excel/Careers/IdolCareer:SoloLv6" = "Breakout Soloist"
    "Gameplay/Excel/Careers/IdolCareer:SoloLv6_Female" = "Breakout Soloist"
    "Gameplay/Excel/Careers/IdolCareer:SoloLv7" = "Anisong Hitmaker"
    "Gameplay/Excel/Careers/IdolCareer:SoloLv7_Female" = "Anisong Hitmaker"
    "Gameplay/Excel/Careers/IdolCareer:SoloLv8" = "Pop Sensation"
    "Gameplay/Excel/Careers/IdolCareer:SoloLv8_Female" = "Pop Sensation"
    "Gameplay/Excel/Careers/IdolCareer:SoloLv9" = "Budokan Headliner"
    "Gameplay/Excel/Careers/IdolCareer:SoloLv9_Female" = "Budokan Headliner"
    "Gameplay/Excel/Careers/IdolCareer:SoloLv10" = "Living Legend"
    "Gameplay/Excel/Careers/IdolCareer:SoloLv10_Female" = "Living Legend"

    # Idol Group Branch Titles (Levels 6-10)
    "Gameplay/Excel/Careers/IdolCareer:GroupLv6" = "Unit Member"
    "Gameplay/Excel/Careers/IdolCareer:GroupLv6_Female" = "Unit Member"
    "Gameplay/Excel/Careers/IdolCareer:GroupLv7" = "Senbatsu Regular"
    "Gameplay/Excel/Careers/IdolCareer:GroupLv7_Female" = "Senbatsu Regular"
    "Gameplay/Excel/Careers/IdolCareer:GroupLv8" = "Unit Leader"
    "Gameplay/Excel/Careers/IdolCareer:GroupLv8_Female" = "Unit Leader"
    "Gameplay/Excel/Careers/IdolCareer:GroupLv9" = "Immortal Center"
    "Gameplay/Excel/Careers/IdolCareer:GroupLv9_Female" = "Immortal Center"
    "Gameplay/Excel/Careers/IdolCareer:GroupLv10" = "National Treasure"
    "Gameplay/Excel/Careers/IdolCareer:GroupLv10_Female" = "National Treasure"

    # --------------------------------------------------------------------------
    # 4. Rich Narrative Promotion & Level Descriptions
    # --------------------------------------------------------------------------
    "Gameplay/Excel/Careers/IdolCareer:EntryLevel" = "Every legend starts somewhere, and for {0.SimName}, that somewhere is outside the train station plaza in a polyester mascot sash handing out neon flyers to hurried commuters. When not bowing ninety degrees to strangers in the drizzle, {0.SimName} spends evenings scrubbing scuff marks off the agency rehearsal floor and practicing basic vocal scales until the night watchman locks the building. Keep your smile bright—someone actually kept your flyer today instead of tossing it in the recycling bin!"
    "Gameplay/Excel/Careers/IdolCareer:EntryLevel_Female" = "Every legend starts somewhere, and for {0.SimName}, that somewhere is outside the train station plaza in a polyester mascot sash handing out neon flyers to hurried commuters. When not bowing ninety degrees to strangers in the drizzle, {0.SimName} spends evenings scrubbing scuff marks off the agency rehearsal floor and practicing basic vocal scales until the night watchman locks the building. Keep your smile bright—someone actually kept your flyer today instead of tossing it in the recycling bin!"

    "Gameplay/Excel/Careers/IdolCareer:PromotionLevel2" = "Put down the stack of street flyers—{0.SimName} has stepped off the sidewalk and onto the stage as a Backup Dancer! Whenever the agency's senior performers take the spotlight, {0.SimName} is right behind them executing razor-sharp formation footwork in 4/4 time. You still haven't been trusted with a live microphone of your own, but memorizing the choreography for seventeen different singles has given you the stamina—and the hunger—to claim the front row."
    "Gameplay/Excel/Careers/IdolCareer:PromotionLevel2_Female" = "Put down the stack of street flyers—{0.SimName} has stepped off the sidewalk and onto the stage as a Backup Dancer! Whenever the agency's senior performers take the spotlight, {0.SimName} is right behind them executing razor-sharp formation footwork in 4/4 time. You still haven't been trusted with a live microphone of your own, but memorizing the choreography for seventeen different singles has given you the stamina—and the hunger—to claim the front row."

    "Gameplay/Excel/Careers/IdolCareer:PromotionLevel3" = "It's time to trade the back row for a live microphone and a spot on the bill! {0.SimName} is now an Underground Idol, performing high-BPM five-song sets in sweltering basement live houses where the ceiling pipes drip condensation and the front-row wota know every call-and-response chant by heart. Between shows, {0.SimName} sells hand-numbered CD-Rs and signs instant Polaroid cheki photos at a folding table until the last train home."
    "Gameplay/Excel/Careers/IdolCareer:PromotionLevel3_Female" = "It's time to trade the back row for a live microphone and a spot on the bill! {0.SimName} is now an Underground Idol, performing high-BPM five-song sets in sweltering basement live houses where the ceiling pipes drip condensation and the front-row wota know every call-and-response chant by heart. Between shows, {0.SimName} sells hand-numbered CD-Rs and signs instant Polaroid cheki photos at a folding table until the last train home."

    "Gameplay/Excel/Careers/IdolCareer:PromotionLevel4" = "Word of {0.SimName}'s electric basement shows has spilled out into the daylight! Promoted to Local Idol, {0.SimName} is now the pride of the town—headlining weekend shopping-arcade festivals, recording cheerful jingles for local merchants, and appearing on community cable broadcasts. Fans in homemade tour shirts now camp out two hours early just to catch {0.SimName}'s outdoor stage sets!"
    "Gameplay/Excel/Careers/IdolCareer:PromotionLevel4_Female" = "Word of {0.SimName}'s electric basement shows has spilled out into the daylight! Promoted to Local Idol, {0.SimName} is now the pride of the town—headlining weekend shopping-arcade festivals, recording cheerful jingles for local merchants, and appearing on community cable broadcasts. Fans in homemade tour shirts now camp out two hours early just to catch {0.SimName}'s outdoor stage sets!"

    "Gameplay/Excel/Careers/IdolCareer:PromotionLevel5" = "Local festival buzz could only stay a secret for so long! Celebrating an official Indie Label Debut, {0.SimName} now has a professionally mastered single, a rooftop music video, custom-tailored stage outfits, and a listening-station display at the local record store. With afternoon radio interviews, weekend Handshake & Cheki sessions, and major record labels scouting every show, {0.SimName} stands on the threshold of stardom!"
    "Gameplay/Excel/Careers/IdolCareer:PromotionLevel5_Female" = "Local festival buzz could only stay a secret for so long! Celebrating an official Indie Label Debut, {0.SimName} now has a professionally mastered single, a rooftop music video, custom-tailored stage outfits, and a listening-station display at the local record store. With afternoon radio interviews, weekend Handshake & Cheki sessions, and major record labels scouting every show, {0.SimName} stands on the threshold of stardom!"

    # Solo Idol Branch Promotions (Levels 6-10)
    "Gameplay/Excel/Careers/IdolCareer:PromotionLevel6Solo" = "Why share the spotlight when you can command the entire stage? {0.SimName} has signed a major-label contract as a Breakout Soloist! With no group formation to hide behind during a three-minute dance break, every breath, pitch change, and camera wink rests squarely on {0.SimName}'s shoulders. Fortunately, your debut single just cracked the Top 10, and you can now book paid Live Concerts at local venues!"
    "Gameplay/Excel/Careers/IdolCareer:PromotionLevel6Solo_Female" = "Why share the spotlight when you can command the entire stage? {0.SimName} has signed a major-label contract as a Breakout Soloist! With no group formation to hide behind during a three-minute dance break, every breath, pitch change, and camera wink rests squarely on {0.SimName}'s shoulders. Fortunately, your debut single just cracked the Top 10, and you can now book paid Live Concerts at local venues!"

    "Gameplay/Excel/Careers/IdolCareer:PromotionLevel7Solo" = "Every late-night anime producer in the country has {0.SimName}'s agency on speed dial! As an Anisong Hitmaker, {0.SimName}'s soaring vocals power the opening themes of three different seasonal anime hits, while {0.SimName}'s smiling face beams down from convenience store displays nationwide. Streaming numbers are in the millions, and overseas convention invitations are pouring in!"
    "Gameplay/Excel/Careers/IdolCareer:PromotionLevel7Solo_Female" = "Every late-night anime producer in the country has {0.SimName}'s agency on speed dial! As an Anisong Hitmaker, {0.SimName}'s soaring vocals power the opening themes of three different seasonal anime hits, while {0.SimName}'s smiling face beams down from convenience store displays nationwide. Streaming numbers are in the millions, and overseas convention invitations are pouring in!"

    "Gameplay/Excel/Careers/IdolCareer:PromotionLevel8Solo" = "You can't turn on a television set or walk past a record shop without seeing {0.SimName}! Now a full-fledged Pop Sensation, {0.SimName} effortlessly juggles chart-topping album releases, glossy fashion magazine covers, and quick-witted banter on prime-time variety panels. Whether belting a power ballad under falling cherry-blossom confetti or charming veteran talk-show hosts, {0.SimName} is a household name—and can now hold massive outdoor Autograph Sessions across town!"
    "Gameplay/Excel/Careers/IdolCareer:PromotionLevel8Solo_Female" = "You can't turn on a television set or walk past a record shop without seeing {0.SimName}! Now a full-fledged Pop Sensation, {0.SimName} effortlessly juggles chart-topping album releases, glossy fashion magazine covers, and quick-witted banter on prime-time variety panels. Whether belting a power ballad under falling cherry-blossom confetti or charming veteran talk-show hosts, {0.SimName} is a household name—and can now hold massive outdoor Autograph Sessions across town!"

    "Gameplay/Excel/Careers/IdolCareer:PromotionLevel9Solo" = "Tickets for {0.SimName}'s solo arena tour sold out in forty-two seconds flat! As a Budokan Headliner, {0.SimName} commands a full live backing band, hydraulic stage lifts, laser shows, and fifteen thousand fans waving synchronized penlights in unison. Critics who once dismissed idols as manufactured pop novelties are now writing thousand-word essays praising {0.SimName}'s vocal artistry and unmatched stage presence."
    "Gameplay/Excel/Careers/IdolCareer:PromotionLevel9Solo_Female" = "Tickets for {0.SimName}'s solo arena tour sold out in forty-two seconds flat! As a Budokan Headliner, {0.SimName} commands a full live backing band, hydraulic stage lifts, laser shows, and fifteen thousand fans waving synchronized penlights in unison. Critics who once dismissed idols as manufactured pop novelties are now writing thousand-word essays praising {0.SimName}'s vocal artistry and unmatched stage presence."

    "Gameplay/Excel/Careers/IdolCareer:PromotionLevel10Solo" = "Bow before the crown: {0.SimName} has ascended to the mythic pinnacle of pop culture as a Living Legend! Arriving at the venue in a chauffeured pink limousine while helicopters film the merchandise queue from above, {0.SimName} defines an entire era of music. From five-night stadium residencies to the closing finale of the New Year's national broadcast, {0.SimName}'s voice is the soundtrack of a generation!"
    "Gameplay/Excel/Careers/IdolCareer:PromotionLevel10Solo_Female" = "Bow before the crown: {0.SimName} has ascended to the mythic pinnacle of pop culture as a Living Legend! Arriving at the venue in a chauffeured pink limousine while helicopters film the merchandise queue from above, {0.SimName} defines an entire era of music. From five-night stadium residencies to the closing finale of the New Year's national broadcast, {0.SimName}'s voice is the soundtrack of a generation!"

    # Idol Group Branch Promotions (Levels 6-10)
    "Gameplay/Excel/Careers/IdolCareer:PromotionLevel6Group" = "Together, you shine ten times brighter! {0.SimName} has been selected to debut in the agency's flagship idol group as a Unit Member! Wearing matching plaid stage outfits and color-coded ribbons, {0.SimName} and the unit rehearse until their footsteps sound like a single heartbeat. You may be stationed on the wing of the V-formation for now, but your dedicated fan club is already pooling votes to push you toward the front row!"
    "Gameplay/Excel/Careers/IdolCareer:PromotionLevel6Group_Female" = "Together, you shine ten times brighter! {0.SimName} has been selected to debut in the agency's flagship idol group as a Unit Member! Wearing matching plaid stage outfits and color-coded ribbons, {0.SimName} and the unit rehearse until their footsteps sound like a single heartbeat. You may be stationed on the wing of the V-formation for now, but your dedicated fan club is already pooling votes to push you toward the front row!"

    "Gameplay/Excel/Careers/IdolCareer:PromotionLevel7Group" = "When the producer read out the lineup for the upcoming single, {0.SimName}'s name was called for the front row! As a Senbatsu Regular, {0.SimName} gets solo camera close-ups during the chorus, a featured verse on the A-side track, and a permanent seat on the group's weekly television variety show. Keep nurturing your unit chemistry—when the front line moves in harmony, the whole theatre shakes!"
    "Gameplay/Excel/Careers/IdolCareer:PromotionLevel7Group_Female" = "When the producer read out the lineup for the upcoming single, {0.SimName}'s name was called for the front row! As a Senbatsu Regular, {0.SimName} gets solo camera close-ups during the chorus, a featured verse on the A-side track, and a permanent seat on the group's weekly television variety show. Keep nurturing your unit chemistry—when the front line moves in harmony, the whole theatre shakes!"

    "Gameplay/Excel/Careers/IdolCareer:PromotionLevel8Group" = "Trusted by the producers and adored by the entire roster, {0.SimName} has been appointed Unit Leader! Not only does {0.SimName} lead the pre-show circle chant and anchor the group's live MC segments, {0.SimName} also sets the standard in rehearsal that keeps every formation razor-sharp. Fans now line up around the block whenever {0.SimName} holds an Autograph or Handshake Session!"
    "Gameplay/Excel/Careers/IdolCareer:PromotionLevel8Group_Female" = "Trusted by the producers and adored by the entire roster, {0.SimName} has been appointed Unit Leader! Not only does {0.SimName} lead the pre-show circle chant and anchor the group's live MC segments, {0.SimName} also sets the standard in rehearsal that keeps every formation razor-sharp. Fans now line up around the block whenever {0.SimName} holds an Autograph or Handshake Session!"

    "Gameplay/Excel/Careers/IdolCareer:PromotionLevel9Group" = "Millions of CD ballot codes were tallied live on national television, and when the confetti cannons fired, {0.SimName} stood at the very apex of the pyramid! As the group's Immortal Center, the entire choreography, costume palette, and music video narrative revolve around {0.SimName}. Standing at Position Zero as the stage curtain drops, {0.SimName} commands the most devoted fandom in the country!"
    "Gameplay/Excel/Careers/IdolCareer:PromotionLevel9Group_Female" = "Millions of CD ballot codes were tallied live on national television, and when the confetti cannons fired, {0.SimName} stood at the very apex of the pyramid! As the group's Immortal Center, the entire choreography, costume palette, and music video narrative revolve around {0.SimName}. Standing at Position Zero as the stage curtain drops, {0.SimName} commands the most devoted fandom in the country!"

    "Gameplay/Excel/Careers/IdolCareer:PromotionLevel10Group" = "{0.SimName} has transcended the idol industry to become a National Treasure! Under {0.SimName}'s leadership, the group has shattered every single-week sales record in music history and sold out the five-major-dome tour in a single morning. Arriving in a sleek executive limousine while billboards across the skyline flash the unit's emblem, {0.SimName} is the beating heart of an idol dynasty that will be remembered forever!"
    "Gameplay/Excel/Careers/IdolCareer:PromotionLevel10Group_Female" = "{0.SimName} has transcended the idol industry to become a National Treasure! Under {0.SimName}'s leadership, the group has shattered every single-week sales record in music history and sold out the five-major-dome tour in a single morning. Arriving in a sleek executive limousine while billboards across the skyline flash the unit's emblem, {0.SimName} is the beating heart of an idol dynasty that will be remembered forever!"

    # --------------------------------------------------------------------------
    # 5. Career Events & Chance Cards (Gameplay/Excel/CareerEvents/IdolCareer:*)
    # --------------------------------------------------------------------------
    # Event 1: The High-Note Gamble
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_VoiceCrack_Desc" = "Midway through a humid afternoon showcase, the sound engineer accidentally mutes the chorus backing track right before the bridge's notoriously difficult whistle-register high note! The crowd is watching closely. Should {0.SimName} step forward to the edge of the stage and belt the high note completely live, or play it safe by harmonizing in a lower register?"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_VoiceCrack_Desc_Female" = "Midway through a humid afternoon showcase, the sound engineer accidentally mutes the chorus backing track right before the bridge's notoriously difficult whistle-register high note! The crowd is watching closely. Should {0.SimName} step forward to the edge of the stage and belt the high note completely live, or play it safe by harmonizing in a lower register?"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_VoiceCrack_Yes" = "Belt the High Note Live"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_VoiceCrack_Yes_Female" = "Belt the High Note Live"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_VoiceCrack_No" = "Harmonize Safely"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_VoiceCrack_No_Female" = "Harmonize Safely"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_VoiceCrack_YesWin" = "Goosebumps! {0.SimName}'s crystal-clear high note rings through the hall without a trace of backing track, leaving the audience stunned before they erupt into thunderous applause. Even Chief Producer-san was seen nodding in admiration from the sound booth!"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_VoiceCrack_YesWin_Female" = "Goosebumps! {0.SimName}'s crystal-clear high note rings through the hall without a trace of backing track, leaving the audience stunned before they erupt into thunderous applause. Even Chief Producer-san was seen nodding in admiration from the sound booth!"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_VoiceCrack_YesLose" = "Ack! Halfway through the note, {0.SimName}'s voice cracks like a startled seagull. {0.SimName} tries to cover it up with an adorable peace-sign pose, but the vocal coach is already scheduling extra scale drills for tomorrow morning."
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_VoiceCrack_YesLose_Female" = "Ack! Halfway through the note, {0.SimName}'s voice cracks like a startled seagull. {0.SimName} tries to cover it up with an adorable peace-sign pose, but the vocal coach is already scheduling extra scale drills for tomorrow morning."
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_VoiceCrack_NoResult" = "{0.SimName} smoothly drops an octave and turns the bridge into a warm, husky alto harmony. It wasn't the showstopping climax the song sheet called for, but the stage manager appreciates {0.SimName}'s cool professionalism under pressure."
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_VoiceCrack_NoResult_Female" = "{0.SimName} smoothly drops an octave and turns the bridge into a warm, husky alto harmony. It wasn't the showstopping climax the song sheet called for, but the stage manager appreciates {0.SimName}'s cool professionalism under pressure."

    # Event 2: The Miracle Fancam
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_ViralFancam_Desc" = "During an outdoor festival performance, {0.SimName} notices a dedicated fan in the front row filming a 4K vertical fancam right as the wind catches {0.SimName}'s stage ribbons. Should {0.SimName} improvise a daring mid-spin ribbon toss and lock eyes with the lens for a 'miracle shot,' or stick strictly to the rehearsed choreography?"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_ViralFancam_Desc_Female" = "During an outdoor festival performance, {0.SimName} notices a dedicated fan in the front row filming a 4K vertical fancam right as the wind catches {0.SimName}'s stage ribbons. Should {0.SimName} improvise a daring mid-spin ribbon toss and lock eyes with the lens for a 'miracle shot,' or stick strictly to the rehearsed choreography?"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_ViralFancam_Yes" = "Strike the Miracle Pose"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_ViralFancam_Yes_Female" = "Strike the Miracle Pose"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_ViralFancam_No" = "Stick to Standard Blocking"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_ViralFancam_No_Female" = "Stick to Standard Blocking"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_ViralFancam_YesWin" = "A once-in-a-decade idol moment! With sunlit confetti swirling around {0.SimName}, the improvised spin and sparkling wink hit the camera frame with cinematic perfection. Within three hours, the clip has two million views, a trending hashtag, and a bonus merchandise royalty check!"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_ViralFancam_YesWin_Female" = "A once-in-a-decade idol moment! With sunlit confetti swirling around {0.SimName}, the improvised spin and sparkling wink hit the camera frame with cinematic perfection. Within three hours, the clip has two million views, a trending hashtag, and a bonus merchandise royalty check!"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_ViralFancam_YesLose" = "Whoops—{0.SimName} misjudged the ribbon toss and ended up with a mouthful of satin streamer right on the downbeat! The fans thought the flustered recovery was endearing, though the dance teacher was less amused."
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_ViralFancam_YesLose_Female" = "Whoops—{0.SimName} misjudged the ribbon toss and ended up with a mouthful of satin streamer right on the downbeat! The fans thought the flustered recovery was endearing, though the dance teacher was less amused."
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_ViralFancam_NoResult" = "{0.SimName} executes the standard choreography with crisp precision. No viral lightning struck today, but the agency choreographer commends {0.SimName}'s textbook discipline."
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_ViralFancam_NoResult_Female" = "{0.SimName} executes the standard choreography with crisp precision. No viral lightning struck today, but the agency choreographer commends {0.SimName}'s textbook discipline."

    # Event 3: Weekly Tabloid Ambush
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_TabloidPaparazzi_Desc" = "Flashbulbs in the night! A photographer from a notorious weekly tabloid ambushes {0.SimName} outside a 24-hour convenience store at midnight, hoping to spin {0.SimName}'s late-night pork-bun run with a voice actor friend into a sensational 'secret romance' scoop. Should {0.SimName} address the cameras head-on with witty humor on tomorrow's morning show, or let the agency's legal department issue a stiff 'no comment'?"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_TabloidPaparazzi_Desc_Female" = "Flashbulbs in the night! A photographer from a notorious weekly tabloid ambushes {0.SimName} outside a 24-hour convenience store at midnight, hoping to spin {0.SimName}'s late-night pork-bun run with a voice actor friend into a sensational 'secret romance' scoop. Should {0.SimName} address the cameras head-on with witty humor on tomorrow's morning show, or let the agency's legal department issue a stiff 'no comment'?"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_TabloidPaparazzi_Yes" = "Charm the Morning Press"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_TabloidPaparazzi_Yes_Female" = "Charm the Morning Press"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_TabloidPaparazzi_No" = "Let Agency Lawyers Handle It"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_TabloidPaparazzi_No_Female" = "Let Agency Lawyers Handle It"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_TabloidPaparazzi_YesWin" = "Masterclass PR! {0.SimName} appears on morning television holding up the exact steamed pork bun from the tabloid photo and jokes that {0.SimName}'s only true midnight romance is with convenience store snacks. The convenience store chain immediately offers {0.SimName} a lucrative endorsement bonus!"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_TabloidPaparazzi_YesWin_Female" = "Masterclass PR! {0.SimName} appears on morning television holding up the exact steamed pork bun from the tabloid photo and jokes that {0.SimName}'s only true midnight romance is with convenience store snacks. The convenience store chain immediately offers {0.SimName} a lucrative endorsement bonus!"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_TabloidPaparazzi_YesLose" = "{0.SimName}'s attempt at a clever joke gets clipped out of context by entertainment blogs, sparking three days of exhausting online discourse before the rumor finally blows over."
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_TabloidPaparazzi_YesLose_Female" = "{0.SimName}'s attempt at a clever joke gets clipped out of context by entertainment blogs, sparking three days of exhausting online discourse before the rumor finally blows over."
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_TabloidPaparazzi_NoResult" = "The agency releases a dry two-sentence fax denying the tabloid's story. The rumor fades quietly by Friday, and the producer appreciates {0.SimName} following standard agency protocol."
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_TabloidPaparazzi_NoResult_Female" = "The agency releases a dry two-sentence fax denying the tabloid's story. The rumor fades quietly by Friday, and the producer appreciates {0.SimName} following standard agency protocol."

    # Event 4: Formation Blocking Showdown (IdolGroup)
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_CenterDispute_Desc" = "Tensions are running high in Studio B! Two of {0.SimName}'s unit mates are locked in a heated dispute over who gets the front-diagonal camera lane during the new single's key dance break, bringing rehearsal to a standstill. Should {0.SimName} step in to redesign the transition so the entire unit shines together, or stay out of the crossfire and practice solo?"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_CenterDispute_Desc_Female" = "Tensions are running high in Studio B! Two of {0.SimName}'s unit mates are locked in a heated dispute over who gets the front-diagonal camera lane during the new single's key dance break, bringing rehearsal to a standstill. Should {0.SimName} step in to redesign the transition so the entire unit shines together, or stay out of the crossfire and practice solo?"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_CenterDispute_Yes" = "Choreograph a Unified Formation"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_CenterDispute_Yes_Female" = "Choreograph a Unified Formation"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_CenterDispute_No" = "Focus on Your Own Angles"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_CenterDispute_No_Female" = "Focus on Your Own Angles"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_CenterDispute_YesWin" = "True leadership! {0.SimName} proposes a rotating kaleidoscope formation that gives both members a dramatic camera close-up before converging around {0.SimName} on the final beat. The unit's chemistry and trust reach an all-time high!"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_CenterDispute_YesWin_Female" = "True leadership! {0.SimName} proposes a rotating kaleidoscope formation that gives both members a dramatic camera close-up before converging around {0.SimName} on the final beat. The unit's chemistry and trust reach an all-time high!"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_CenterDispute_YesLose" = "Both unit mates complain that {0.SimName}'s revised formation is too complicated to learn before tomorrow's music video shoot, leaving the dressing room atmosphere a little frosty."
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_CenterDispute_YesLose_Female" = "Both unit mates complain that {0.SimName}'s revised formation is too complicated to learn before tomorrow's music video shoot, leaving the dressing room atmosphere a little frosty."
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_CenterDispute_NoResult" = "{0.SimName} stays by the mirror perfecting solo footwork while the choreographer settles the argument. {0.SimName}'s own lines look razor-sharp, though the unit feels a bit distant."
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_CenterDispute_NoResult_Female" = "{0.SimName} stays by the mirror perfecting solo footwork while the choreographer settles the argument. {0.SimName}'s own lines look razor-sharp, though the unit feels a bit distant."

    # Event 5: Blackout at the Arena (SoloIdol)
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_AcousticEncore_Desc" = "Disaster strikes during the climax of {0.SimName}'s solo showcase! A sudden power surge trips the venue's main audio amplifier, plunging the stage into silence with thousands of fans waiting in the dark. Should {0.SimName} walk to the very edge of the stage apron, set down the dead wireless mic, and sing an unaccompanied a cappella ballad to the silent hall, or wait backstage while technicians replace the fuse?"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_AcousticEncore_Desc_Female" = "Disaster strikes during the climax of {0.SimName}'s solo showcase! A sudden power surge trips the venue's main audio amplifier, plunging the stage into silence with thousands of fans waiting in the dark. Should {0.SimName} walk to the very edge of the stage apron, set down the dead wireless mic, and sing an unaccompanied a cappella ballad to the silent hall, or wait backstage while technicians replace the fuse?"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_AcousticEncore_Yes" = "Sing Unaccompanied A Cappella"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_AcousticEncore_Yes_Female" = "Sing Unaccompanied A Cappella"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_AcousticEncore_No" = "Wait for Stage Technicians"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_AcousticEncore_No_Female" = "Wait for Stage Technicians"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_AcousticEncore_YesWin" = "Pure magic! As {0.SimName} raises a finger to the lips, the entire arena falls pin-drop silent, illuminated only by a gentle galaxy of glowing penlights. {0.SimName}'s raw, unamplified voice carries to the very top balcony, moving fans to tears and cementing {0.SimName}'s status as a once-in-a-generation vocalist!"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_AcousticEncore_YesWin_Female" = "Pure magic! As {0.SimName} raises a finger to the lips, the entire arena falls pin-drop silent, illuminated only by a gentle galaxy of glowing penlights. {0.SimName}'s raw, unamplified voice carries to the very top balcony, moving fans to tears and cementing {0.SimName}'s status as a once-in-a-generation vocalist!"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_AcousticEncore_YesLose" = "The fans in the back rows can't quite hear {0.SimName} over the hum of the emergency generators and start chanting for the sound crew instead, leaving {0.SimName} hoarse when the speakers finally pop back on."
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_AcousticEncore_YesLose_Female" = "The fans in the back rows can't quite hear {0.SimName} over the hum of the emergency generators and start chanting for the sound crew instead, leaving {0.SimName} hoarse when the speakers finally pop back on."
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_AcousticEncore_NoResult" = "{0.SimName} waves apologetically and steps into the wings for ten minutes while the crew swaps the amplifier fuse. Once power returns, the show finishes without a hitch."
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_AcousticEncore_NoResult_Female" = "{0.SimName} waves apologetically and steps into the wings for ten minutes while the crew swaps the amplifier fuse. Once power returns, the show finishes without a hitch."

    # Event 6: The 1,000-Ticket Superfan Queue
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_HandshakeMarathon_Desc" = "It's 8:00 PM at the convention center, and the line for {0.SimName}'s Handshake & Cheki lane still stretches all the way out to the parking lot! The venue staff offer to cut the queue off at the scheduled closing bell. Should {0.SimName} insist on staying overtime until every last fan has received their handshake and smiling Polaroid, or close the booth on schedule to protect {0.SimName}'s voice and stamina?"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_HandshakeMarathon_Desc_Female" = "It's 8:00 PM at the convention center, and the line for {0.SimName}'s Handshake & Cheki lane still stretches all the way out to the parking lot! The venue staff offer to cut the queue off at the scheduled closing bell. Should {0.SimName} insist on staying overtime until every last fan has received their handshake and smiling Polaroid, or close the booth on schedule to protect {0.SimName}'s voice and stamina?"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_HandshakeMarathon_Yes" = "Greet Every Last Fan!"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_HandshakeMarathon_Yes_Female" = "Greet Every Last Fan!"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_HandshakeMarathon_No" = "Close the Booth on Schedule"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_HandshakeMarathon_No_Female" = "Close the Booth on Schedule"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_HandshakeMarathon_YesWin" = "Kami-taiou (God-tier fan service)! Not only does {0.SimName} greet every single fan with radiant energy, {0.SimName} even remembers their nicknames and favorite B-side tracks. Word of {0.SimName}'s devotion spreads across fan forums overnight, sending CD pre-orders skyrocketing!"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_HandshakeMarathon_YesWin_Female" = "Kami-taiou (God-tier fan service)! Not only does {0.SimName} greet every single fan with radiant energy, {0.SimName} even remembers their nicknames and favorite B-side tracks. Word of {0.SimName}'s devotion spreads across fan forums overnight, sending CD pre-orders skyrocketing!"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_HandshakeMarathon_YesLose" = "{0.SimName} makes it through the entire line, though by fan #980 {0.SimName}'s cheek muscles are cramping and {0.SimName} can barely lift an arm. The fans appreciate the effort, but {0.SimName} is completely exhausted!"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_HandshakeMarathon_YesLose_Female" = "{0.SimName} makes it through the entire line, though by fan #980 {0.SimName}'s cheek muscles are cramping and {0.SimName} can barely lift an arm. The fans appreciate the effort, but {0.SimName} is completely exhausted!"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_HandshakeMarathon_NoResult" = "Staff lower the velvet rope right at 8:00 PM and hand out refund vouchers to the remaining queue. {0.SimName} gets home in time for a full night's sleep, though a few fans grumble on social media."
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_HandshakeMarathon_NoResult_Female" = "Staff lower the velvet rope right at 8:00 PM and hand out refund vouchers to the remaining queue. {0.SimName} gets home in time for a full night's sleep, though a few fans grumble on social media."

    # Reward Events (7-10)
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_BSideChartTopper_Desc" = "Surprise sleeper hit! A quirky B-side track that {0.SimName} recorded in a single late-night take has been picked up by thousands of short-form dance creators online, propelling the single back up the charts and earning {0.SimName} a handsome royalty bonus!"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_BSideChartTopper_Desc_Female" = "Surprise sleeper hit! A quirky B-side track that {0.SimName} recorded in a single late-night take has been picked up by thousands of short-form dance creators online, propelling the single back up the charts and earning {0.SimName} a handsome royalty bonus!"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_LuxurySponsorGift_Desc" = "After {0.SimName} casually mentioned a favorite lip gloss during a backstage livestream, the brand sold out nationwide in three hours! Grateful executives sent a luxury endorsement bonus and a bouquet of roses to {0.SimName}'s dressing room."
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_LuxurySponsorGift_Desc_Female" = "After {0.SimName} casually mentioned a favorite lip gloss during a backstage livestream, the brand sold out nationwide in three hours! Grateful executives sent a luxury endorsement bonus and a bouquet of roses to {0.SimName}'s dressing room."
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_AnimeThemeTieIn_Desc" = "The creditless opening sequence for this season's biggest fantasy anime—featuring {0.SimName}'s high-energy theme song—just crossed ten million views! Digital downloads and CD singles are flying off the shelves."
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_AnimeThemeTieIn_Desc_Female" = "The creditless opening sequence for this season's biggest fantasy anime—featuring {0.SimName}'s high-energy theme song—just crossed ten million views! Digital downloads and CD singles are flying off the shelves."
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_SynchronizedFormation_Desc" = "A fan-made slow-motion analysis video of your unit's latest live performance went viral after proving that {0.SimName} and the group hit a 99.8% synchronized jump angle during the final chorus! Producer-san is ecstatic, and unit morale is through the roof!"
    "Gameplay/Excel/CareerEvents/IdolCareer:IdolEvent_SynchronizedFormation_Desc_Female" = "A fan-made slow-motion analysis video of your unit's latest live performance went viral after proving that {0.SimName} and the group hit a 99.8% synchronized jump angle during the final chorus! Producer-san is ecstatic, and unit morale is through the roof!"

    # --------------------------------------------------------------------------
    # 6. Custom Opportunities (Gameplay/Excel/Opportunities/Names:* & OpportunitiesSetup:*)
    # --------------------------------------------------------------------------
    "Gameplay/Excel/Opportunities/Names:IdolOpp_Generic_Failure" = "In the fast-paced idol industry, missed schedules mean missed spotlights! The producer had to hand the booking to another agency trainee."

    # Opportunity 1: Late Night Flyer Blitz
    "Gameplay/Excel/Opportunities/Names:IdolOpp_LateNightFlyerBlitz_Name" = "Hand-Drawn Flyers at the Plaza"
    "Gameplay/Excel/Opportunities/Names:IdolOpp_LateNightFlyerBlitz_Description" = "The agency's basement showcase only has twelve seats reserved for Friday night! Producer-san wants {1.SimName} to head down to the Bookstore plaza with a stack of hand-illustrated flyers and indie demo CDs to win over passersby face-to-face."
    "Gameplay/Excel/Opportunities/Names:IdolOpp_LateNightFlyerBlitz_Hint" = "Visit the Bookstore to Pass Out Hand-Drawn Idol Flyers."
    "Gameplay/Excel/Opportunities/Names:IdolOpp_LateNightFlyerBlitz_Completion" = "{1.SimName}'s infectious smile and handwritten notes turned hurried shoppers into curious fans! Every seat at Friday's showcase is now reserved, earning {1.SimName} a cash bonus, career performance, and new local buzz!"
    "Gameplay/Excel/Opportunities/Names:IdolOpp_LateNightFlyerBlitz_Progress" = "Distribute Promotional Flyers at the Bookstore"
    "Gameplay/Excel/Opportunities/OpportunitiesSetup:IdolOpp_LateNightFlyerBlitz_Interaction" = "Pass Out Hand-Drawn Idol Flyers"

    # Opportunity 2: Convenience Store Campaign
    "Gameplay/Excel/Opportunities/Names:IdolOpp_ConvenienceStoreCampaign_Name" = "Konbini Collaboration Campaign"
    "Gameplay/Excel/Opportunities/Names:IdolOpp_ConvenienceStoreCampaign_Description" = "A local grocery and convenience store chain is launching a limited-edition 'Idol Berry Melonpan' pastry line! They've invited {1.SimName} to record the hourly in-store chime announcement and pose beside the life-size cardboard cutout display."
    "Gameplay/Excel/Opportunities/Names:IdolOpp_ConvenienceStoreCampaign_Hint" = "Visit the Grocery Store to Record the Konbini Campaign."
    "Gameplay/Excel/Opportunities/Names:IdolOpp_ConvenienceStoreCampaign_Completion" = "Shoppers couldn't resist {1.SimName}'s cheerful in-store voice broadcast—the entire shelf of Idol Berry Melonpan sold out before noon! The sponsor happily paid out a promotional bonus and boosted {1.SimName}'s Celebrity Fame."
    "Gameplay/Excel/Opportunities/Names:IdolOpp_ConvenienceStoreCampaign_Progress" = "Film Konbini Collaboration at the Grocery Store"
    "Gameplay/Excel/Opportunities/OpportunitiesSetup:IdolOpp_ConvenienceStoreCampaign_Interaction" = "Record Konbini Idol Campaign"

    # Opportunity 3: Stamina Bootcamp
    "Gameplay/Excel/Opportunities/Names:IdolOpp_StaminaBootcamp_Name" = "Two-Hour Encore Stamina Bootcamp"
    "Gameplay/Excel/Opportunities/Names:IdolOpp_StaminaBootcamp_Description" = "True idols never let the audience hear them catch their breath on the microphone—even after eighteen consecutive high-tempo dance tracks! The agency trainer has booked the Stadium steps for {1.SimName} to complete the legendary 'Singing While Sprinting' endurance bootcamp."
    "Gameplay/Excel/Opportunities/Names:IdolOpp_StaminaBootcamp_Hint" = "Visit the Stadium to Complete the Idol Stamina Bootcamp."
    "Gameplay/Excel/Opportunities/Names:IdolOpp_StaminaBootcamp_Completion" = "Not a single shaky note, even at the top of the stadium bleachers! {1.SimName}'s lung capacity, Athletic stamina, and stage endurance have reached pro-level heights."
    "Gameplay/Excel/Opportunities/Names:IdolOpp_StaminaBootcamp_Progress" = "Complete the Idol Stamina Bootcamp at the Stadium"
    "Gameplay/Excel/Opportunities/OpportunitiesSetup:IdolOpp_StaminaBootcamp_Interaction" = "Complete Idol Vocal-Stamina Bootcamp"

    # Opportunity 4: Anisong Theme Tie-In (SoloIdol)
    "Gameplay/Excel/Opportunities/Names:IdolOpp_AnisongThemeTieIn_Name" = "Seasonal Anime Opening Recording"
    "Gameplay/Excel/Opportunities/Names:IdolOpp_AnisongThemeTieIn_Description" = "A major animation studio is looking for a soaring, high-BPM solo vocal to anchor the opening credits of their flagship autumn fantasy series! Head to the Theatre soundstage to record the 89-second TV-size cut and full single version."
    "Gameplay/Excel/Opportunities/Names:IdolOpp_AnisongThemeTieIn_Hint" = "Visit the Theatre to Record the Anime Opening Theme."
    "Gameplay/Excel/Opportunities/Names:IdolOpp_AnisongThemeTieIn_Completion" = "From the dramatic acappella intro to the key-change chorus, {1.SimName} nailed the recording in two takes! The anime director is already predicting the song will top the seasonal Anisong awards."
    "Gameplay/Excel/Opportunities/Names:IdolOpp_AnisongThemeTieIn_Progress" = "Record the Anime Opening Theme at the Theatre"
    "Gameplay/Excel/Opportunities/OpportunitiesSetup:IdolOpp_AnisongThemeTieIn_Interaction" = "Record Seasonal Anime Opening Theme"

    # Opportunity 5: Variety Reaction Queen/Star
    "Gameplay/Excel/Opportunities/Names:IdolOpp_VarietyReactionQueen_Name" = "Morning Variety Panelist Spot"
    "Gameplay/Excel/Opportunities/Names:IdolOpp_VarietyReactionQueen_Description" = "The producers of the network's top-rated morning variety show need a charismatic Idol guest who can deliver camera-ready reactions, survive the 'Ultra-Wasabi Roulette' segment with grace, and plug the agency's new release in thirty seconds flat!"
    "Gameplay/Excel/Opportunities/Names:IdolOpp_VarietyReactionQueen_Hint" = "Visit the Journalism / Business Building to Film the Variety Show."
    "Gameplay/Excel/Opportunities/Names:IdolOpp_VarietyReactionQueen_Completion" = "{1.SimName}'s hilarious one-liners and picture-perfect 'picture-in-picture' corner reactions stole the entire broadcast! The network has already invited {1.SimName} back as a recurring guest."
    "Gameplay/Excel/Opportunities/Names:IdolOpp_VarietyReactionQueen_Progress" = "Film the Morning Variety Segment at the Business/Journalism Building"
    "Gameplay/Excel/Opportunities/OpportunitiesSetup:IdolOpp_VarietyReactionQueen_Interaction" = "Film Idol Variety TV Segment"

    # Opportunity 6: Center Position Audition (IdolGroup)
    "Gameplay/Excel/Opportunities/Names:IdolOpp_CenterPositionAudition_Name" = "Senbatsu Center Showcase"
    "Gameplay/Excel/Opportunities/Names:IdolOpp_CenterPositionAudition_Description" = "Formation spots for the group's milestone anniversary single are up for grabs! Chief Producer-san is holding a closed-door showcase at the Theatre to see who possesses the gravitational stage aura required to command the coveted Center position."
    "Gameplay/Excel/Opportunities/Names:IdolOpp_CenterPositionAudition_Hint" = "Visit the Theatre to Audition for the Senbatsu Center Spot."
    "Gameplay/Excel/Opportunities/Names:IdolOpp_CenterPositionAudition_Completion" = "From the moment the stage lights hit {1.SimName}, the producers couldn't look anywhere else! {1.SimName}'s commanding performance secured front-row Center honors and huge respect from the agency brass."
    "Gameplay/Excel/Opportunities/Names:IdolOpp_CenterPositionAudition_Progress" = "Perform at the Senbatsu Center Showcase at the Theatre"
    "Gameplay/Excel/Opportunities/OpportunitiesSetup:IdolOpp_CenterPositionAudition_Interaction" = "Perform Senbatsu Center Audition"

    # Opportunity 7: Golden Week Handshake Festival
    "Gameplay/Excel/Opportunities/Names:IdolOpp_GoldenWeekHandshake_Name" = "Golden Week Handshake Festival"
    "Gameplay/Excel/Opportunities/Names:IdolOpp_GoldenWeekHandshake_Description" = "Thousands of fans carrying stacks of CD participation tickets have gathered at the City Hall civic plaza for the annual Golden Week Idol Festival! Put on your brightest stage smile and head over to host a special VIP handshake and cheki session."
    "Gameplay/Excel/Opportunities/Names:IdolOpp_GoldenWeekHandshake_Hint" = "Visit City Hall to Host the Golden Week Handshake Festival."
    "Gameplay/Excel/Opportunities/Names:IdolOpp_GoldenWeekHandshake_Completion" = "What a turnout! {1.SimName}'s booth had the longest queue at the entire festival, setting a new single-day merchandise record and propelling {1.SimName}'s Celebrity Fame into the stratosphere!"
    "Gameplay/Excel/Opportunities/Names:IdolOpp_GoldenWeekHandshake_Progress" = "Host the Golden Week Handshake Festival at City Hall"
    "Gameplay/Excel/Opportunities/OpportunitiesSetup:IdolOpp_GoldenWeekHandshake_Interaction" = "Host Golden Week Idol Handshake Festival"

    # Opportunity 8: Countdown Dome Festival
    "Gameplay/Excel/Opportunities/Names:IdolOpp_CountdownDomeFestival_Name" = "New Year's Dome Countdown Extravaganza"
    "Gameplay/Excel/Opportunities/Names:IdolOpp_CountdownDomeFestival_Description" = "This is the stage every idol dreams of from their very first day in the rehearsal room: headlining the nationally televised Countdown Dome Festival at the Stadium before fifty thousand synchronized penlights and millions of viewers at home!"
    "Gameplay/Excel/Opportunities/Names:IdolOpp_CountdownDomeFestival_Hint" = "Visit the Stadium to Headline the Countdown Dome Festival."
    "Gameplay/Excel/Opportunities/Names:IdolOpp_CountdownDomeFestival_Completion" = "As silver streamer cannons fired across the Stadium roof and fifty thousand fans chanted {1.SimName}'s name in unison, history was made! The performance earned §4,500, massive Celebrity Fame, and a permanent place in idol history!"
    "Gameplay/Excel/Opportunities/Names:IdolOpp_CountdownDomeFestival_Progress" = "Headline the Countdown Dome Festival at the Stadium"
    "Gameplay/Excel/Opportunities/OpportunitiesSetup:IdolOpp_CountdownDomeFestival_Interaction" = "Headline Dome Idol Extravaganza"

    # --------------------------------------------------------------------------
    # 7. Custom Lifetime Wishes (Major Dreams)
    # --------------------------------------------------------------------------
    "Gameplay/Dreams/8e51a101:GenericName" = "Living Legend"
    "Gameplay/Dreams/8e51a101:GenericName_Female" = "Living Legend"
    "Gameplay/Dreams/8e51a101:FemaleName" = "Reach level 10 in the Idol career track (Solo Idol branch)."
    "Gameplay/Dreams/8e51a101:FemaleName_Female" = "Reach level 10 in the Idol career track (Solo Idol branch)."
    "Gameplay/Dreams/8e51a101:MaleName" = ""
    "Gameplay/Dreams/8e51a101:MaleName_Female" = ""
    "Gameplay/Dreams/8e51a101:Description" = "Countless hopefuls step up to the microphone with dreams of stardom, yet only a once-in-a-generation prodigy can command a packed arena stage entirely alone. Your Sim must survive grueling trainee rehearsals, conquer the charts as a Solo Idol, and captivate millions of fans to become a Living Legend."
    "Gameplay/Dreams/8e51a101:Description_Female" = "Countless hopefuls step up to the microphone with dreams of stardom, yet only a once-in-a-generation prodigy can command a packed arena stage entirely alone. Your Sim must survive grueling trainee rehearsals, conquer the charts as a Solo Idol, and captivate millions of fans to become a Living Legend."

    "Gameplay/Dreams/8e51a102:GenericName" = "National Treasure"
    "Gameplay/Dreams/8e51a102:GenericName_Female" = "National Treasure"
    "Gameplay/Dreams/8e51a102:FemaleName" = "Reach level 10 in the Idol career track (Idol Group branch)."
    "Gameplay/Dreams/8e51a102:FemaleName_Female" = "Reach level 10 in the Idol career track (Idol Group branch)."
    "Gameplay/Dreams/8e51a102:MaleName" = ""
    "Gameplay/Dreams/8e51a102:MaleName_Female" = ""
    "Gameplay/Dreams/8e51a102:Description" = "An idol group shines brightest when every voice and formation step moves in flawless harmony, led by an unshakable Center at the apex of the pyramid. Your Sim must rise from the back row of the rehearsal studio, unite their fellow unit members, and triumph in the General Election to become a beloved National Treasure."
    "Gameplay/Dreams/8e51a102:Description_Female" = "An idol group shines brightest when every voice and formation step moves in flawless harmony, led by an unshakable Center at the apex of the pyramid. Your Sim must rise from the back row of the rehearsal studio, unite their fellow unit members, and triumph in the General Election to become a beloved National Treasure."
}

Write-Host "Loaded $($strings.Count) localized string definitions." -ForegroundColor Green

# ==============================================================================
# 5. ASSEMBLE PACKAGE RESOURCES
# ==============================================================================
Write-Host "`nCreating package: $OutputPath..." -ForegroundColor Yellow

$pkg = [s3pi.Package.Package]::NewPackage(0)
$nameMap = New-Object NameMapResource.NameMapResource(0, $null)

# 1. Add Compiled S3SA Script Assembly (0x073FAA07)
$dllBytes = [System.IO.File]::ReadAllBytes($DllPath)
$scriptRes = New-Object ScriptResource.ScriptResource(0, $null)
$msDll = New-Object System.IO.MemoryStream(,$dllBytes)
$scriptRes.Assembly = New-Object System.IO.BinaryReader($msDll)
$scriptInstance = Get-SimHash64 "IdolCareerMod"
$rkScript = New-ResourceKey 0x073FAA07 0x00000000 $scriptInstance
$pkg.AddResource($rkScript, $scriptRes.Stream, $true) | Out-Null
$nameMap.Add([uint64]$scriptInstance, "IdolCareerMod")
Write-Host ("  [+] S3SA: IdolCareerMod (0x{0:X16}, {1} bytes)" -f $scriptInstance, $dllBytes.Length)

# 2. Add _XML Resources (0x0333406C)
$xmlFiles = @(
    @{ Name = "IdolCareerData"; Path = (Join-Path $ProjectDir "XML\IdolCareerData.xml") },
    @{ Name = "IdolCareerEvents"; Path = (Join-Path $ProjectDir "XML\IdolCareerEvents.xml") },
    @{ Name = "IdolOpportunities"; Path = (Join-Path $ProjectDir "XML\IdolOpportunities.xml") },
    @{ Name = "Sims3.Gameplay.Careers.IdolCareerMod"; Path = (Join-Path $ProjectDir "XML\Sims3.Gameplay.Careers.IdolCareerMod.xml") },
    @{ Name = "Sims3.Gameplay.Careers.IdolCareer"; Path = (Join-Path $ProjectDir "XML\Sims3.Gameplay.Careers.IdolCareer.xml") }
)

foreach ($xf in $xmlFiles) {
    if (-not (Test-Path $xf.Path)) {
        throw "XML file not found: $($xf.Path)"
    }
    $xmlInstance = Get-SimHash64 $xf.Name
    $xmlBytes = [System.IO.File]::ReadAllBytes($xf.Path)
    $msXml = New-Object System.IO.MemoryStream(,$xmlBytes)
    $rkXml = New-ResourceKey 0x0333406C 0x00000000 $xmlInstance
    $pkg.AddResource($rkXml, $msXml, $true) | Out-Null
    $nameMap.Add([uint64]$xmlInstance, [string]$xf.Name)
    Write-Host ("  [+] _XML: {0} (0x{1:X16}, {2} bytes)" -f $xf.Name, $xmlInstance, $xmlBytes.Length)
}

# 3. Add Custom Icon _IMAG Resources (0x2F7D0004)
$iconFiles = @(
    @{ Name = "w_idol_career"; Path = (Join-Path $ProjectDir "Icons\w_idol_career.png") },
    @{ Name = "w_simple_idol_career_s"; Path = (Join-Path $ProjectDir "Icons\w_simple_idol_career_s.png") },
    @{ Name = "w_lifetime_idol_solo"; Path = (Join-Path $ProjectDir "Icons\w_lifetime_idol_solo.png") },
    @{ Name = "w_lifetime_idol_group"; Path = (Join-Path $ProjectDir "Icons\w_lifetime_idol_group.png") }
)

foreach ($ic in $iconFiles) {
    if (-not (Test-Path $ic.Path)) {
        throw "Icon file not found: $($ic.Path)"
    }
    $imgInstance = Get-SimHash64 $ic.Name
    $imgBytes = [System.IO.File]::ReadAllBytes($ic.Path)
    $msImg = New-Object System.IO.MemoryStream(,$imgBytes)
    $rkImg = New-ResourceKey 0x2F7D0004 0x00000000 $imgInstance
    $pkg.AddResource($rkImg, $msImg, $true) | Out-Null
    $nameMap.Add([uint64]$imgInstance, [string]$ic.Name)
    Write-Host ("  [+] _IMAG: {0} (0x{1:X16}, {2} bytes)" -f $ic.Name, $imgInstance, $imgBytes.Length)
}

# 4. Build STBL Resources (0x220557DA) for all 22 Sims 3 Locales (0x00..0x15)
$baseStblHash = (Get-SimHash64 "IdolCareerMod_Strings") -band [uint64]0x00FFFFFFFFFFFFFF

$stblTemplate = New-Object StblResource.StblResource(0, $null)
foreach ($kvp in $strings.GetEnumerator()) {
    $keyHash = Get-SimHash64 $kvp.Key
    $stblTemplate.Add([uint64]$keyHash, [string]$kvp.Value)
}
$stblBytes = $stblTemplate.AsBytes

for ($locale = 0; $locale -le 0x15; $locale++) {
    $stblInstance = ([uint64]$locale -shl 56) -bor $baseStblHash
    $msStbl = New-Object System.IO.MemoryStream(,$stblBytes)
    $rkStbl = New-ResourceKey 0x220557DA 0x00000000 $stblInstance
    $pkg.AddResource($rkStbl, $msStbl, $true) | Out-Null
    $nameMap.Add([uint64]$stblInstance, ("IdolCareerStrings_Locale_0x{0:X2}" -f $locale))
}
Write-Host ("  [+] STBL: 22 locales generated (0x00..0x15, {0} localized strings each)" -f $stblTemplate.Count)

# 5. Add _KEY NameMap Resource (0x0166038C)
$nmInstance = Get-SimHash64 "IdolCareerMod_NameMap"
$rkNm = New-ResourceKey 0x0166038C 0x00000000 $nmInstance
$pkg.AddResource($rkNm, $nameMap.Stream, $true) | Out-Null
Write-Host ("  [+] _KEY: NameMap (0x{0:X16})" -f $nmInstance)

# 6. Save & Close Package
$pkg.SaveAs($OutputPath)
[s3pi.Package.Package]::ClosePackage(0, $pkg)

$finalSize = (Get-Item $OutputPath).Length
Write-Host "`nPackage built successfully!" -ForegroundColor Green
Write-Host "Location: $OutputPath" -ForegroundColor Green
Write-Host "Size    : $finalSize bytes ($([Math]::Round($finalSize / 1KB, 2)) KB)`n" -ForegroundColor Green
