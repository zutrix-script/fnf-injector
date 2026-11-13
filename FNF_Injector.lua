--[[
    ╔══════════════════════════════════════════════════════╗
    ║         FNF ANIMATION INJECTOR v7.2                  ║
    ║  Arrow HUD • Dynamic Face • Anim Maker • Leg Lock    ║
    ║  + Idle BPM Speed Control                             ║
    ║  + Live Preview • Favorites • Playlist • Themes       ║
    ║  + Hold-to-Loop + Weighted Alt Animations (per bind)  ║
    ║  + Dynamic Spacing System (search/toggle/presets)     ║
    ║  + Full Silhouette Mode (CAM tab)                     ║
    ║  + NEW: Safe re-inject + UNLOAD (title bar)           ║
    ║  + NEW: Real FNF arrows, notes, splashes and icons    ║
    ║  + NEW: ARMS tab: mix animations into your poses      ║
    ║  + NEW: STAGE tab: BF, GF & opponent, screen or world ║
    ║  + NEW: Strum engine • the game's hold notes          ║
    ║  + NEW: Ride lock v4: others see you stuck on it      ║
    ║  + NEW: COPY tab: copy a player's moves               ║
    ╚══════════════════════════════════════════════════════╝

    ARMS: each note can play up to three animation layers together
    with its pose. Layers in the pose's own layer blend into it
    joint by joint (MIX %), so the pose keeps going while a layer
    brings in its arms; OVER layers sit on top. A layer can freeze
    on a frame like a pose, or play through, and SPEED layers grow
    the faster you pose. It's all animations, so everyone sees it.
    LOCAL AIM points your arms by turning the joints directly, seen
    from your camera; only you see that one.

    STAGE: BF, GF and an opponent (Dad, Spooky, Tricky, Sonic.exe,
    any baked character) can stand IN THE GAME as billboards only
    your client has, or stay ON SCREEN. GF sways to the beat, BF
    sings what you press, the opponent sings when your RP opponent
    poses. Arrows: a strum engine plays the game's own animations
    (press, confirm, held glow, hold-cover sparks) on your strip and
    the opponent's. Holding a key gives the game's hold trail, out
    from under its arrow, and holding builds health, faster the
    longer you hold.
    Sprites are local files made by the scripts in tools/.

    v7.2.2
      * FLY tab > AIR COMBAT: hand-to-hand in the air with your FNF
        opponent, for RP. The health bars are only on your screen;
        nobody takes real damage. Your notes are jabs that dash you
        at them; their notes knock you back with a hit animation.
        The same arrow at the same moment is a CLASH: you teleport
        somewhere else mid-air. Lose and you're KO'd mid-air, then
        you fall. 1 round, best of 3 or best of 5.

    v7.2.1
      * FLY tab: fly around (move keys, Space up, Ctrl down) and
        every pose moves you its way. FACE TO FACE faces your
        opponent and steps you left and right around them; SIDE TO
        SIDE faces the screen and moves you screen left and right.
        UP and DOWN go up and down. You still hit walls.
      * One tab failing to build no longer stops the tabs after it.

    v7.2
      * COPY tab: pick a player and COPY MOVES plays what they're
        playing on your character, on the same frame, so everyone
        sees you copy them. Or send any animation they play into
        one of your directions (BINDS or the cutter), one at a
        time, or FILL the next four.
      * Idle animations are saved: the ID, and if it was looping
        it starts again when you load and when you respawn. SAVE
        IDLE keeps a list of idles, with their BPM, to pick from.
      * CUTTER SLOTS: eight slots that each keep a whole cutter
        setup. Idles and cutter slots live in library.json, the
        same on every save slot.
      * Holding a note keeps building health, faster the longer
        you hold it (CAM tab > HEALTH BAR, the three HOLD sliders).

    v7.1 — RIDE LOCK v4 (CAM tab): other players see you stuck on
    the object instead of sliding off it. Saves from v7.0 load as
    they are.
      * The pose that's sent is written right after physics too, so
        what leaves your client is exactly the pose meant for them,
        and your body stops colliding while locked so nothing nudges
        it on the way.
      * GUESS: where the object will be by the time they see you.
        ROUTE learns a route it repeats (trains, lifts, platforms)
        and knows the next bend, stop and loop; CURVE follows bends
        and braking; LINE is v7.0's straight line. AUTO picks.
      * SIT IF SEAT: a free passenger seat on the object is used
        instead. The game welds you there: exact for everyone.
      * THEIR VIEW: a glowing ghost where other players see you.
      * WALLS: walking on it stops at its walls.

    v7.0 — stability and speed. Nothing was removed and saves from
    v6.x load as they are.
      * FNF SPRITES (Settings > ARROW HUD): the arrow strip, the
        notes that fly off it and the hit splashes use the game's
        own art, and the health-bar icon boxes take a character
        name (bf, dad, gf, pico ...) as well as a decal ID. The
        images are local files in workspace/FNFInjector/sprites,
        so only you see them. Without them the drawn arrows stay.
      * Running the script twice no longer stacks two copies: the
        new one shuts the old one down first.
      * UNLOAD in the title bar removes the script and hands the
        camera, your character and Roblox's UI back, no rejoin.
      * A note you were holding lets go when chat opens or the
        window loses focus, instead of sticking on.
      * Sliders, the theme list and the visualizers no longer do
        work that nobody can see (see the notes beside each).
]]

-- ============================================================
--  SERVICES & GLOBALS
-- ============================================================
local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService      = game:GetService("SoundService")
local Lighting          = game:GetService("Lighting")
local Workspace         = game:GetService("Workspace")
local LocalPlayer      = Players.LocalPlayer
local PlayerGui        = LocalPlayer:WaitForChild("PlayerGui")

-- Single namespace table for every top-level function.
-- Luau allows only 200 locals per function scope; this keeps the
-- main chunk far under that ceiling.
local F = {}

-- ============================================================
--  SESSION — one copy at a time, and a clean way out
--
--  Executing the script a second time used to leave the first copy
--  running underneath: every key press played two animations, two
--  cameras fought over the view and every loop ran double. Each
--  copy now registers itself, a new one shuts the old one down
--  first, and UNLOAD (title bar) puts the game back with no rejoin.
-- ============================================================
F.alive = true     -- every background loop runs `while F.alive`
F.owned = {}       -- connections and instances this copy created

-- Remember a connection or an instance so unload can clean it up.
-- Returns what it was given, so it wraps any expression in place.
function F.own(x)
    if not F.alive then
        -- unloaded while something was still being built (a second copy was
        -- executed before this one finished starting): nothing new survives
        pcall(function()
            if typeof(x) == "RBXScriptConnection" then x:Disconnect() else x:Destroy() end
        end)
        return x
    end
    local owned = F.owned
    if #owned >= 400 then
        -- respawns and re-picked opponents retire things all the time; drop
        -- what's already dead so the list stays short. The newest few stay
        -- regardless: a fresh ScreenGui has no Parent for a moment.
        local keep, n = {}, #owned
        for i, o in ipairs(owned) do
            local live
            if typeof(o) == "RBXScriptConnection" then
                live = o.Connected
            else
                live = (o.Parent ~= nil)
            end
            if live or i > n - 8 then keep[#keep + 1] = o end
        end
        F.owned = keep
        owned = keep
    end
    owned[#owned + 1] = x
    return x
end

-- Shut this copy down. Features switch themselves off first (F.teardown,
-- defined above LAUNCH where it can see all of them), then every connection
-- and instance the script made is removed.
function F.unload(why)
    if not F.alive then return end
    F.alive = false
    if F.teardown then pcall(F.teardown) end
    for _, o in ipairs(F.owned) do
        pcall(function()
            if typeof(o) == "RBXScriptConnection" then o:Disconnect() else o:Destroy() end
        end)
    end
    F.owned = {}
    pcall(function()
        local env = getgenv()
        if env.FNFInjectorSession == F.session then env.FNFInjectorSession = nil end
    end)
    print("[FNF] Injector unloaded" .. (why and (" (" .. tostring(why) .. ")") or "") .. ".")
end

do
    local env
    pcall(function() env = getgenv() end)
    if type(env) ~= "table" then env = _G end

    local old
    pcall(function() old = env.FNFInjectorSession end)
    if type(old) == "table" and type(old.unload) == "function" then
        F.replacedOld = pcall(old.unload, "replaced by a newer copy")
        task.wait()   -- give its last deferred callbacks a frame to finish
    end
    -- a copy from before v7 can't be asked to unload; all we can do is
    -- notice its panel and say so once ours is up
    F.legacyCopy = (PlayerGui:FindFirstChild("FNFInjectorGui") ~= nil)

    F.session = { unload = function(why) F.unload(why) end }
    pcall(function() env.FNFInjectorSession = F.session end)
end

-- ============================================================
--  DEFAULT BINDINGS
-- ============================================================
local DEFAULT_BINDINGS = {
    { dir = "LEFT",  key = "Z", id = "243827693" },
    { dir = "DOWN",  key = "X", id = "182724289" },
    { dir = "UP",    key = "C", id = "183412246" },
    { dir = "RIGHT", key = "V", id = "243656287" },
}
local CurrentBindings = {}
for _, v in ipairs(DEFAULT_BINDINGS) do
    table.insert(CurrentBindings, { dir = v.dir, key = v.key, id = v.id, speedMult = 1, holdLoop = false,
        alts = {},          -- extra animations for this note: { id = "...", chance = n }
        mode = "CYCLE",     -- CYCLE / RANDOM / WEIGHTED
        cycleIdx = 0 })
end

-- ============================================================
--  SONG SECTIONS — switchable animation sets
-- ============================================================
local sections = {
    { name = "Default",  ids = { LEFT="204062532", DOWN="204292303", UP="183412246", RIGHT="218504594" } },
    { name = "Intro",    ids = { LEFT="0", DOWN="0", UP="0", RIGHT="0" } },
    { name = "Verse",    ids = { LEFT="0", DOWN="0", UP="0", RIGHT="0" } },
    { name = "Chorus",   ids = { LEFT="0", DOWN="0", UP="0", RIGHT="0" } },
    { name = "Bridge",   ids = { LEFT="0", DOWN="0", UP="0", RIGHT="0" } },
}
local currentSectionIdx  = 1
local sectionNextKey     = "RightBracket"  -- ] to go next
local sectionPrevKey     = "LeftBracket"   -- [ to go prev

-- ============================================================
--  STATE
-- ============================================================
local SpacingSystem          -- ★ forward-declared so F.setupCharacter can see it
local SPACING                -- forward-declared: the save code above its definition needs it
local INJECTOR_VERSION = "7.2.2"   -- up here so everything can read it
local animTracks   = {}
local idleTrack    = nil
local connections  = {}
local animator     = nil
local character    = nil
local spacing      = nil
local rebindingRow = nil
local guiVisible   = true
local idleLooping  = false

-- EMOTE CUTTER STATE
local cutterEnabled  = false
local cutterAnimId   = "138338762910112"
local cutterTrack    = nil
local cutterSlices   = {
    LEFT  = { start = 0, stop = 0.5, id = "" },
    DOWN  = { start = 0.5, stop = 1.0, id = "" },
    UP    = { start = 1.0, stop = 1.5, id = "" },
    RIGHT = { start = 1.5, stop = 2.0, id = "" },
}
local cutterPreviewTrack = nil

-- SOLO MODE STATE
local soloActive     = false
local soloKey        = "G"       -- default keybind
local soloCamDist    = 6         -- how close the camera zooms in
local soloCamHeight  = 2         -- height offset during solo
local soloCamFOV     = 45        -- tight FOV for drama
local soloLetterbox  = 0.12      -- letterbox bar size during solo
local soloTransition = 0.6       -- seconds to ease in/out

-- ============================================================
--  SILHOUETTE MODE STATE  (rebuilt)
-- ============================================================
function F.silZ(n) return math.clamp(n, 0, 200) end  -- hard ZIndex ceiling

local silhouetteActive = false
local silhouetteKey    = "H"
local silhouetteBlend  = 0

local SilFX = {
    strength        = 1,      -- master intensity 0..1
    fadeSpeed       = 4,      -- how fast it eases in/out
    includePlayer   = true,
    includeOpponent = true,
    alwaysOnTop     = true,   -- cut-outs render through geometry
    fillColor       = Color3.new(0, 0, 0),

    -- improvements
    outline      = false,                       -- a visible outline around each cut-out
    outlineColor = Color3.fromRGB(255, 255, 255),
    splitColors  = false,                       -- you and your opponent in different colours
    playerColor  = Color3.fromRGB(0, 200, 255),
    oppColor     = Color3.fromRGB(255, 60, 90),
    spotlight    = false,                       -- dark screen, light around you both
    spotDim      = 0.75,
    spotGui = nil, spotRings = nil,
}

-- runtime handles + methods live here so we don't burn top-level locals
local Sil = { cc = nil, blur = nil, conn = nil, highlights = {}, flashGui = nil }

-- ============================================================
--  CHAOS CAMERA STATE
--  Everything lives on one table — the main chunk is near
--  Luau's 200-local ceiling, so this costs a single register.
-- ============================================================

-- ============================================================
--  HEALTH BAR STATE — FNF-style drain with sliding icons
-- ============================================================
local Health = {
    enabled = true,
    key     = "B",
    hp      = 0.5,          -- 0 = dead, 1 = maxed
    display = 0.5,          -- smoothed value the bar actually draws
    gainPerNote    = 0.035, -- your note pushes you forward
    drainPerPose   = 0.055, -- their pose pushes you back
    passiveDrain   = 0.012, -- per second
    smooth  = 8,
    playerIcon = "", oppIcon = "",   -- optional decal IDs

    -- holding a note keeps building health, faster the longer you hold
    holdRate  = 0.02,   -- health a second when a hold starts (0 = holding adds nothing)
    holdCurve = 1.5,    -- how fast that speeds up: x e^(holdCurve) for every second held
    holdMax   = 0.25,   -- it never builds faster than this a second
    holds     = {},     -- [dir] = when that note was pressed

    -- drive the real Roblox health bar from the rap battle
    portraits     = true,      -- avatar headshots on the icons
    portraitSpot  = "BESIDE",  -- BESIDE the bar ends, or ON the bar (sliding)
    portraitP = "", portraitO = "", portraitFor = nil, portraitLoop = false,

    lowVignette   = true,   -- red screen edges as the bar empties
    vignetteAt    = 0.2,    -- starts creeping in below this much health
    vig = {},

    syncRoblox    = true,   -- your Humanoid health follows this bar
    respectDamage = true,   -- real game damage also lowers the rap health
    lastWritten   = nil,    -- what we last set, so we can tell the game's numbers from ours
    real          = nil,    -- your real health, as the game last sent it
    realFor       = nil,    -- the Humanoid that number belongs to

    gui = nil, fillP = nil, fillO = nil,
    iconP = nil, iconO = nil, warn = nil, conn = nil,
}

-- ============================================================
--  PERFECT DOUBLE NOTE STATE — afterimage on a frame-tight double
-- ============================================================
local Ghost = {
    enabled  = true,
    window   = 0.02,   -- seconds; two presses inside this = perfect
    life     = 0.45,   -- how long the afterimage lasts
    distance = 6,      -- studs it travels
    lastPress = 0, lastDir = nil, lastSpawn = 0,
    tint = Color3.fromRGB(120, 240, 255),

    -- FE DASH, the part other players see (see Ghost.dash)
    feDash       = false,
    dashStyle    = "TELEPORT",  -- TELEPORT: snap out and back. SLIDE: a quick glide each way
    dashDistance = 4,           -- studs
    dashHold     = 0.15,        -- seconds away, long enough for the server to pass it on
    dashGen      = 0,
}

-- ============================================================
--  RIDE STATE v4 — hard lock to an object, seen by everyone
-- ============================================================
local Ride = {
    enabled  = false,          -- true while locked on
    key      = "R",

    walkWith   = true,         -- walk around on the object
    jumpWith   = true,         -- jump and land back on it, still carried
    clampEdges = true,         -- can't walk off the edge
    edgeMargin = 0.8,
    gravityScale = 1,
    pickRadius = 14,           -- if nothing's under you, grab the nearest part

    shake = true, wind = true, speedFov = true, gLean = true,
    maxSpeedAt = 120, minSpeed = 4,
    shakeScale = 1, windScale = 1, leanScale = 1,

    -- live
    part = nil,
    localPos = Vector3.new(0, 0, 0),   -- where you stand, in the object's own space
    yaw = 0,                           -- which way you face, in the object's space
    yOff = 0, vy = 0, grounded = true, -- jump arc, also in object space
    lastPos = nil, lastVel = Vector3.new(0, 0, 0), lateralG = 0,
    speed = 0, smooth = 0,
    wasAnchored = false, walkTrack = nil, jumpConn = nil,
    stepConn = nil,                                  -- runs just before physics
    platVel = Vector3.new(0, 0, 0),                  -- what the object is doing, world space
    walkVel = Vector3.new(0, 0, 0),                  -- your own walking, world space
    savedAutoRotate = nil, savedStates = nil,

    -- ping compensation: other players see you one round trip behind the object
    pingComp   = true,   -- send your position ahead of the object by your ping
    pingScale  = 1,      -- 1 = exactly your ping; tune up or down to taste
    maxLead    = 0.6,    -- never lead by more than this many seconds
    pingMs     = 0, leadStuds = 0, lastPingT = 0,
    pingSource = "MINE",     -- MINE is the right number; AVERAGE kept as an option
    extraMs    = 50,         -- your screen shows other objects slightly late; this covers that
    pingCount  = 1, pingOthers = false, warnedOthers = false,
    leadTime   = 0,                        -- seconds ahead the replicated pose is predicted
    lastCF     = nil,                      -- the object's pose last frame
    platAng    = Vector3.new(0, 0, 0),     -- the object's spin, world space (rad/s)
    turnDeg    = 0,                        -- spin in degrees/s, for the readout

    -- our own animations while locked (the default falling one would win otherwise)
    tracks = nil, currentAnim = nil,
    bindName = "FNFRideLock",
    gui = nil, streaks = {}, readout = nil,

    -- v4: what other players see (see RIDE v4)
    guess     = "AUTO",    -- AUTO, ROUTE, CURVE or LINE: how the object's next moves are guessed
    seatFirst = false,     -- if it has a free passenger seat, sit in it: exact for everyone
    walls     = true,      -- walking on it stops at its walls instead of going through
    noCollide = true,      -- your body doesn't collide while locked, so the sent pose stays exact
    showView  = false,     -- a ghost where other players see you, and how far off that is
    routeSecs = 90,        -- seconds of the object's path remembered for ROUTE

    -- live (v4)
    accel = 0, dwell = 0, leadFresh = false,
    hist = nil, histPart = nil, hLastT = 0,
    matchLag = nil, matchCheckT = 0, matchSearchT = 0, routePeriod = 0,
    kind = "", kFrames = 0, kStale = 0,
    seat = nil, seatTry = nil, seatUntil = 0,
    collideParts = nil, wallParams = nil, postConn = nil,
    viewModel = nil, sentLog = {}, viewGap = 0,
}

-- ============================================================
--  FLY STATE (see FLY)
-- ============================================================
local Fly = {
    enabled    = false,
    key        = "F",
    speed      = 20,        -- studs a second with the move keys (40 at most)
    lookFly    = true,      -- forward goes where the camera looks, up or down too
    poseMove   = true,      -- your poses move you: LEFT, DOWN, UP, RIGHT
    poseDist   = 4,         -- studs a pose moves you
    poseTime   = 0.18,      -- seconds that move takes
    layout     = "FACE",    -- FACE: face to face with your opponent; SIDE: side to side, facing the screen
    returnHome = true,      -- drift back to your spot when you let go of the note
    returnTime = 0.35,      -- seconds the way back takes
    snapCut    = false,     -- a pose that cuts into another's move puts you at its spot at once
    hover      = true,      -- a gentle bob while you hang there
    lean       = true,      -- tilt into your moves
    anims      = true,      -- your character's swim animation while flying

    -- live
    root = nil, hum = nil, att = nil, lv = nil, conn = nil, savedAuto = nil,
    home = nil, pos = nil, retOff = nil, held = {}, lastPose = 0, rot = nil, tilt = nil,
    partnerRoot = nil, partnerT = 0, facing = "", snapPending = false,
    tracks = nil, curAnim = nil, refreshUI = nil,
}

-- ============================================================
--  AIR COMBAT STATE (see AIR COMBAT)
-- ============================================================
local Air = {
    rounds      = 3,        -- 1, 3 or 5: best of
    damage      = 4,        -- % of a health bar each hit takes
    dashDist    = 5,        -- studs a jab dashes you at them (never faster than 40 studs a second)
    knock       = 3,        -- studs their hit knocks you back
    koHold      = 1.5,      -- seconds you hang there KO'd before you fall
    circle      = true,     -- slowly circle each other
    circleSpeed = 12,       -- degrees a second
    keepClose   = true,     -- fly too far off and you're pulled back toward them
    maxDist     = 30,       -- studs
    sameArrow   = true,     -- a clash needs the same arrow (when it can tell which arrow they hit)
    clashWindow = 0.15,     -- seconds apart your note and theirs can be and still clash
    tpDist      = 10,       -- studs a clash teleports you, at most
    jabLEFT = "", jabDOWN = "", jabUP = "", jabRIGHT = "",   -- "" = that arrow's own pose
    hitAnim     = "",       -- "" = your character's own fall animation
    koAnim      = "",       -- "" = your character's fall animation, held still
    winAnim     = "",       -- "" = your character's cheer

    -- live
    on = false, state = "OFF", foe = nil, foeConn = nil, foeCharConn = nil, gen = 0,
    round = 1, winsMe = 0, winsThem = 0, hpMe = 1, hpThem = 1,
    off = Vector3.new(0, 0, 0), kbVel = Vector3.new(0, 0, 0), tilt = 0, tiltKick = 0,
    dash = nil, drop = nil, ko = false, falling = false,
    mine = {}, theirs = {}, taught = {}, taughtFor = nil, teach = nil, teachUsed = {},
    lagT = 0, lagV = 0.15, hitN = 0, bannerN = 0,
    tracks = {}, tracksFor = nil, hud = nil, refreshUI = nil,
}

-- ============================================================
--  CUTTER PREVIEW STATE — scrub an animation frame by frame
-- ============================================================
local Cut = {
    vp = nil, wm = nil, cam = nil, clone = nil, animator = nil, track = nil,
    length = 0,          -- seconds, read from the loaded track
    playhead = 0,
    playing = false,
    loopSlice = false,   -- when playing, loop only the selected slice
    selDir = "LEFT",
    yaw = 0,             -- preview model rotation
    fps = 30,            -- frame step for the < > buttons

    -- every note can have its own animation; blank means "use the default"
    editId  = "",        -- the animation currently loaded in the preview
    tracks  = {},        -- [animId] = gameplay track on your own animator
    trackOwner = nil,    -- the Animator those tracks were loaded on
    idBoxes = {},

    -- gameplay response
    reach    = 0.1,      -- seconds a slice takes to reach its pose when you press
    snap     = false,    -- skip straight to the pose, no motion at all
    sliceGen = 0,        -- bumps on every press so stale watchers bow out

    -- play the slice back to its start frame after it lands
    reverse     = "OFF",   -- OFF / AUTO / RELEASE
    returnPause = 0.08,    -- AUTO: how long it sits on the pose before going back
    returnTime  = 0.25,    -- seconds the trip back takes
    sliceStart  = 0,       -- start frame of the slice currently playing
    holdAfterReturn = true, -- freeze on the start frame once it's back
    conn = nil,

    -- ui handles, filled in by the tab builder
    bar = nil, head = nil, timeLbl = nil, frameLbl = nil,
    sliceFrames = {}, startBoxes = {}, stopBoxes = {}, dirBtns = {},
    playBtn = nil, lenLbl = nil, statusLbl = nil,
}

-- ============================================================
--  POSE HOLD STATE
-- ============================================================
local Hold = {
    enabled   = true,
    duration  = 5,      -- seconds a short pose stays up after you let go
    shortAt   = 1.5,    -- clips this long or shorter count as "short"
    holdAll   = false,  -- ignore the length check, hold everything
    cutter    = true,   -- hold cutter slices too
    fadeOut   = 0.18,   -- blend when the hold expires naturally
    untilNext = false,  -- ignore the timer: hold until the next pose replaces it

    track = nil, label = nil, releaseAt = 0, token = 0, conn = nil,
}

-- ============================================================
--  POSE RESPONSE STATE
-- ============================================================
local Pose = {
    reach  = 0.06,    -- seconds a pose takes to land (was a fixed 0.17)
    snap   = false,   -- land on the final frame instantly, no motion
    cache  = {},      -- [animId..loopFlag] = track, so a pose never reloads
    owner  = nil,     -- the Animator the cache belongs to

    -- plain dodge animation, played from the BINDS tab key
    dodgeKey   = "Q",
    dodgeId    = "",
    dodgeSpeed = 1,
}

-- ============================================================
--  ARROW HUD STATE — draggable strip + travelling notes
-- ============================================================
local Arrows = {
    -- anchor: scale picks the screen corner, offset nudges from it
    x = 0.5, y = 1, offX = 0, offY = -82,

    size = 64, hitSize = 74, gap = 14,

    draggable   = true,
    noteEnabled = true,
    noteDir     = "DOWN",   -- DOWN or UP
    noteSpeed   = 420,      -- pixels per second
    noteLife    = 0.55,
    trail       = true,

    beatBob = true,   -- strip breathes on the beat
    splash  = true,   -- ring pops out of the arrow on hit
    combo   = true,   -- running hit counter above the strip
    tilt    = true,   -- strip leans toward whichever arrow you hit
    sprites = true,   -- the game's own arrows, when they're in the sprites folder

    -- the opponent's strip: always there in songs, and in free play when on
    -- (it lights up when your RP opponent poses). Dragged like yours.
    oppShow = false,
    oppX = 0.5, oppY = 1, oppOffX = -400, oppOffY = -82,
    oppContainer = nil, oppFrames = nil,

    container = nil, noteLayer = nil, comboLbl = nil,
    comboCount = 0, lastHit = 0, tiltVel = 0, tiltPos = 0,
}

-- ============================================================
--  FNF SPRITES STATE — the real arrows, notes, splashes, icons
--  Cut from your own copy of the game (tools/make_fnf_sprites.py)
--  into FNFInjector/sprites in the executor's workspace and loaded
--  with getcustomasset. That makes them local files on your client:
--  nobody else sees them and nothing is uploaded to Roblox.
-- ============================================================
local Skin = {
    folder = "FNFInjector/sprites",
    cache  = {},     -- [file name] = content id, or false when it isn't there
    gen    = {},     -- [dir] = press counter, so a late frame swap can't undo a newer one

    -- every strum / note sprite sits on a 256 px canvas with the arrow
    -- ~157 px wide on it; splashes are on a 320 px one at the same scale
    strumScale  = 256 / 157,
    splashScale = 320 / 157,
    coverScale  = 512 / 157,   -- hold-cover sparks
    splashFps   = 24,
}

-- ============================================================
--  STAGE STATE — Boyfriend, Girlfriend and the opponent
--  Baked frame by frame from the game's own character files by
--  tools/make_fnf_characters.py into the sprites folder. GF sways
--  to the beat, BF sings whatever you press, and the opponent
--  sings their side of a song (or reacts to your RP opponent).
-- ============================================================
local Chars = {
    enabled    = false,     -- on all the time, not just during songs
    showOpp    = true,      -- the opponent stands opposite them
    freeOpp    = "dad",     -- the opponent outside songs: any baked character
    mode       = "SCREEN",  -- SCREEN: drawn over the game. WORLD: standing in the game world
    follow     = false,     -- WORLD: the stage moves with you instead of staying where it was put
    scale      = 1,         -- SCREEN size
    worldScale = 1,         -- WORLD size
    x = 1, y = 1, offX = -24, offY = -150,             -- SCREEN: bottom-right corner of BF & GF
    oppX = 0, oppY = 1, oppOffX = 24, oppOffY = -150,  -- SCREEN: bottom-left corner of the opponent
    draggable  = true,

    -- WORLD: where each one stands, in studs from you (you face -Z): GF at
    -- the back in the middle, the opponent on the left, BF on the right
    WORLD_SPOTS = { gf = Vector3.new(0, 0, -16), opp = Vector3.new(-9, 0, -10), bf = Vector3.new(9, 0, -10) },

    meta = nil, gui = nil, world = nil, anchor = nil, conn = nil, dragConns = nil,
    slots = nil, oppId = nil, lastBeat = nil,
}

-- ============================================================
--  ARMS STATE — animations mixed into your poses, and local aim
--  MIXED ANIMATIONS (everyone sees): layers that play together
--  with each note's pose and blend into it, made of animations,
--  which is all Roblox sends other players.
--  LOCAL AIM (only you see): turns your arm joints to point the
--  way you set, as seen from your camera, over everything else.
--  Both can follow how fast you're posing; pose speed never
--  changes.
-- ============================================================
local Arms = {
    -- MIXED ANIMATIONS: the part everyone sees. Each note can play up to three
    -- animation layers together with its pose. Layers in the pose's own layer
    -- blend with it joint by joint by weight (Roblox mixes tracks of the same
    -- priority), so the pose keeps going while a layer brings its arms in;
    -- "over" layers sit above the pose instead. Each slot:
    --   id     animation ID ("" = empty slot)
    --   share  % of the result it gets where it and the pose move the same joint
    --   at     % into the animation it freezes at, like a pose (-1: plays through)
    --   over   false: mixed into the pose. true: laid over it
    --   speed  true: the faster you pose, the more of it you get
    mixOn = true,
    mix = {},
    mixFade = 0.15,    -- seconds the layers take to leave once the pose ends

    enabled = false,   -- LOCAL AIM (below): only you see it
    -- Per note: which arm reaches out and where it points, seen from your
    -- camera. h: around you (0 = screen right, 90 = at the camera,
    -- 180 = screen left, 270 = into the screen). v: up (+) / down (-).
    -- arm: AUTO (the arm on the side it points to), LEFT, RIGHT or BOTH.
    dirs = {
        LEFT  = { arm = "AUTO", h = 180, v = 15,  max = 100 },
        DOWN  = { arm = "AUTO", h = 90,  v = -35, max = 100 },
        UP    = { arm = "AUTO", h = 20,  v = 75,  max = 100 },
        RIGHT = { arm = "AUTO", h = 0,   v = 15,  max = 100 },
    },

    calm    = 0.35,   -- how far the arm goes when posing slowly (0-1)
    full    = 1,      -- ...and when posing fast
    slowNps = 2,      -- notes per second that count as slow
    fastNps = 7,      -- ...and as fast
    window  = 1.2,    -- seconds of recent presses your speed is measured over
    blendIn = 0.06,   -- seconds the arm takes to get there
    fadeOut = 0.2,    -- seconds it takes to go back into the pose
    straighten = 0.8, -- how straight the elbow goes at full reach (R15 rigs)
    firstPerson = true, -- keep your arms on screen when the camera is in your head

    -- live
    presses = {}, speed = 0, reachNow = 0, down = {}, dir = nil, active = false,
    alpha = 0, previewUntil = 0, joints = nil, jointsFor = nil, conn = nil, viewBound = false,
    mixTracks = {}, mixOwner = nil, mixActive = {}, mixGen = 0,
}
for _, dir in ipairs({ "LEFT", "DOWN", "UP", "RIGHT" }) do
    Arms.mix[dir] = {}
    for i = 1, 3 do
        Arms.mix[dir][i] = { id = "", share = 50, at = 100, over = false, speed = false }
    end
end

-- ============================================================
--  HOLD TRAILS STATE — the game's hold notes, in free play
--  Hold a note key and the game's own hold trail comes out of
--  that arrow, the arrow plays its held glow and the hold-cover
--  sparks run on it, exactly as on a hold note in a song. Let go
--  and the trail is pulled back in. Health keeps building while
--  you hold, faster the longer you hold (Health.holdStep).
-- ============================================================
local Notes = {
    enabled = true,
    key     = "M",

    startDelay = 0.12,   -- shorter than this is a tap: no trail
    fullTime   = 0.5,    -- seconds for the trail to reach full length
    length     = 170,    -- trail length when full, in pixels
    grow       = "UP",   -- UP: the trail runs up the screen. DOWN: down it

    -- live
    held = {},           -- [dir] = { start, active, tail, piece, cap }
    layer = nil, conn = nil,
}

-- ============================================================
--  INTRO STATE — loading screen + first-time tour
-- ============================================================
local Intro = {
    seen            = false,  -- has this player finished (or skipped) the tour?
    backdropOpacity = 0.5,    -- loading screen backdrop, 0.5 = 50%
    titleOpacity    = 0.5,    -- the title slams in at 50%
    duration        = 2.9,    -- seconds the loading screen runs

    loadGui = nil, loadDone = false, skip = false,
    tourGui = nil, step = 1, pulse = nil,
}

-- ============================================================
--  VIDEO PLAYER STATE — local video files, only you see them
-- ============================================================
local Vid = {
    folder  = "FNFInjector/videos",   -- the drop box, inside your executor's workspace
    volume  = 0.6,
    opacity = 0,          -- 0 = solid, 1 = invisible
    looped  = true,
    display = "WINDOW",   -- WINDOW / FULLSCREEN / BACKDROP
    scale   = 1,          -- window size multiplier
    lastFile = "",

    -- black screen fade
    boKey     = "L",
    boFadeIn  = 0.35,     -- seconds to go black
    boHold    = 0.4,      -- seconds fully black
    boFadeOut = 2.5,      -- seconds to slowly come back
    boToken   = 0,

    -- video stage: you + your opponent drawn over the video
    stage = { on = false, gui = nil, vp = nil, cam = nil, me = nil, opp = nil,
              prevDisplay = nil, watch = nil },

    -- live
    gui = nil, window = nil, frame = nil, bar = nil, timeLbl = nil,
    boGui = nil, current = nil, api = {},
}

-- ============================================================
--  RESULT STATE — win / lose, your call
-- ============================================================
local Result = {
    winKey  = "Y",
    loseKey = "U",

    -- win
    cheerId   = "",      -- blank = your avatar's own cheer (works anywhere)
    cheerLoop = false,
    cheerTime = 3,       -- seconds to keep cheering when looping

    -- lose
    sitId      = "",     -- blank = your avatar's own sit
    flingSpeed = 96,     -- studs/s  (96 ≈ 60 mph)
    lift       = 45,     -- upward kick, studs/s
    spin       = 12,     -- tumble, radians/s
    direction  = "AWAY", -- AWAY from opponent / BACK / RANDOM
    getUpAfter = 2.5,    -- seconds before you recover

    banner = true,       -- big YOU WIN / YOU LOSE text

    -- live
    gui = nil, bannerLbl = nil, winTrack = nil, sitTrack = nil, token = 0,
}

-- ============================================================
--  MOBILE STATE — FNF-style touch arrows
-- ============================================================
local Mobile = {
    mode      = "AUTO",  -- AUTO (phones/tablets only) / ON / OFF
    size      = 1,       -- arrow size multiplier
    spread    = 0.2,     -- gap between the two pairs, as a share of screen width
    pairGap   = 14,      -- pixels between the two arrows in a pair
    bottom    = 18,      -- pixels up from the bottom edge
    idleFade  = 0.15,    -- how see-through an arrow is when you're not touching it
    hideStrip = false,   -- hide the top arrow strip while the touch arrows are up
    layoutMode  = "SPLIT", -- SPLIT (FNF), LEFT-handed (all on the left), RIGHT-handed
    haptics     = true,    -- a short buzz on each hit, where the device supports it
    landscape   = true,    -- lock the phone to landscape while the arrows are up
    hideDesktop = true,    -- hide keyboard-only UI and start with the panel folded
    hapticMotor = nil, prevOrientation = nil, didFold = false,

    -- live
    gui = nil, btns = {}, touches = {}, held = {}, active = false,
}

-- ============================================================
--  MENU SIZE STATE — the panel fits whatever screen it's on
-- ============================================================
local Menu = {
    auto  = true,   -- shrink to fit small screens (phones), never grow past normal
    scale = 1,      -- your own size on top of that
    main = nil, scaleObj = nil, current = 1, clamping = false,
    W = 440, H = 620,
}

-- ============================================================
--  CAMERA 2.0 STATE
-- ============================================================
local Cam2 = {
    -- beat pulses (extends Beat Zoom)
    pulseEvery = 1,       -- pulse every N beats (1, 2 or 4)
    beatShake  = 0,       -- a small vertical bump on each pulse, 0 = off

    -- opponent zoom-ins
    oppZoom      = true,
    oppZoomPower = 8,     -- FOV dip when your opponent poses
    oppAim       = 0.35,  -- how far the camera turns toward them (0..1)
    oppDecay     = 5,

    -- directional screen shake
    dirShake      = true,
    dirShakePower = 0.35, -- studs
    shakeFreq     = 42,
    shakeDecay    = 11,

    -- distance follows health
    healthDist    = false,
    healthClosest = 0.6,  -- distance multiplier when your bar is empty

    -- intro / outro shots
    introStyle = "SWOOP", outroStyle = "PULLBACK",
    shotTime   = 2.2,     -- seconds to fly in / out
    outroHold  = 2.5,     -- seconds the outro holds before returning
    orbitDegPerSec = 35,
    outroOnResult   = true,   -- WIN / LOSE plays the outro
    introOnOpponent = false,  -- picking an opponent plays the intro
    introKey = "O", outroKey = "P",

    -- saved camera setups: { { name = "...", data = {...} }, ... }
    presets = {},

    -- live
    shot = nil, oppAmt = 0, shakeAmp = 0, shakeT = 0,
    shakeAxis = Vector2.new(1, 0), beatN = 0,
}

-- ============================================================
--  CUTSCENE STATE — hide the UI, let it play like a music video
-- ============================================================
local Cutscene = {
    key        = "J",
    hideRoblox = true,    -- also hide Roblox's own UI (chat, backpack...)
    bars       = true,    -- cinematic black bars
    active = false, saved = {}, core = {}, gui = nil,
}

-- ============================================================
--  IDLE SAVE STATE — your idle animation comes back with you
-- ============================================================
local Idle = {
    id   = "",        -- the idle animation in the box
    auto = false,     -- it was looping: start it again on load and after you respawn
    box = nil, statusLbl = nil, listFrame = nil, syncBpmUI = nil,
}

-- ============================================================
--  LIBRARY STATE — saved idles and cutter slots
--  Kept in a file of their own (workspace/FNFInjector/library.json)
--  so they're the same whichever save slot you're on.
-- ============================================================
local Lib = {
    CUT_SLOTS = 8,
    idles  = {},      -- { name, id, bpm, base }, newest first
    cutter = {},      -- [1..CUT_SLOTS] = { name, id, slices = { LEFT = { start, stop, id }, ... } }
    warned = false,
}

-- ============================================================
--  COPY STATE — do what another player does
-- ============================================================
local Copy = {
    on      = false,    -- COPY MOVES: your character plays what they play
    target  = nil,      -- the player
    walkToo = false,    -- also copy their walk, run, idle, jump and fall
    sync    = true,     -- keep your copy on the same frame as theirs
    speed   = 1,        -- your copy's speed against theirs
    into    = "BINDS",  -- where the arrow buttons put an animation: BINDS or CUTTER
    -- live
    fill = nil, fillUsed = {},  -- directions waiting for their next poses
    seen = {},                  -- their animations, newest first: { id, name, length, count, bad }
    names = {},                 -- [id] = catalog name (false while it's being looked up)
    links = {},                 -- [their track] = your track
    tracks = {}, tracksFor = nil,
    animr = nil, conn = nil, charConn = nil, leaveConn = nil, syncConn = nil,
    refresh = nil, redrawQueued = false,
}

-- ============================================================
--  SAVE SYSTEM STATE v2
-- ============================================================
local Save = {
    folder    = "FNFInjector",
    slot      = 1,
    slots     = 3,
    autoSave  = true,
    interval  = 20,        -- seconds between autosave checks
    useFolder = false,     -- set at boot if the executor can make folders
    api       = {},        -- resolved file functions, see Save.resolveApi
    available = false,
    lastJson  = nil,       -- last thing we wrote, so autosave skips no-op writes
    lastSaved = "never",
    lastLoaded = "never",
    lastError = nil,
    autoThread = nil,
}

-- ============================================================
--  KEYBIND REGISTRY + ON-SCREEN CHEAT SHEET
-- ============================================================
local Keys = {
    overlayKey = "Backquote",   -- the ` key, left of 1
    beatKey    = "Semicolon",   -- toggle the beat zoom
    overlayOn  = false,
    opacity    = 0.55,          -- panel transparency; higher = more see-through

    -- intro transitions
    intro = {
        { name = "COUNTDOWN", key = "One",   label = "3-2-1-GO!" },
        { name = "WIPE",      key = "Two",   label = "Diagonal wipe" },
        { name = "PIXELATE",  key = "Three", label = "Pixel dissolve" },
        { name = "FLASH",     key = "Four",  label = "Flash bang" },
        { name = "SPLIT",     key = "Five",  label = "VS split" },
    },

    -- cinematic presets, in CAM_PRESET_ORDER order
    preset = {
        { name = "Two Shot",       key = "Six" },
        { name = "Over Shoulder",  key = "Seven" },
        { name = "Shot / Reverse", key = "Eight" },
        { name = "Slow Push",      key = "Nine" },
        { name = "Low Hero",       key = "Zero" },
        { name = "Crane",          key = "Minus" },
        { name = "Directional",    key = "Equals" },
        { name = "Snappy",         key = "Quote" },
        { name = "First Person",   key = "BackSlash" },
    },

    gui = nil, list = nil, panel = nil,
}

-- ============================================================
--  BOSS BATTLE CUTSCENE STATE
--  Opponent towers over you, camera on the floor looking up.
-- ============================================================
local Boss = {
    active      = false,
    key         = "N",
    oppScale    = 2.6,    -- how tall the opponent becomes
    playerScale = 0.75,   -- how small you become
    dist        = 7,      -- camera distance behind you
    height      = 1.0,    -- camera height (low = looking up)
    lookHeight  = 7,      -- how far up the opponent we frame
    bars        = 0.17,   -- letterbox during the cutscene
    blend       = 0,
    savedOpp    = 1, savedPlayer = 1,
    scaledOpp   = nil, scaledPlayer = nil,
}

-- ============================================================
--  SPLIT SCREEN STATE
--  Roblox renders the world through one CurrentCamera, so a real
--  split is impossible. These are ViewportFrames showing cloned
--  characters with their animations mirrored live — no map.
-- ============================================================
local Split = {
    enabled = false,
    key     = "K",
    dist      = 7,    -- how far each viewport camera sits back
    height    = 2.5,
    rotL      = -65,  -- your clone's yaw in degrees (negative = turned right)
    rotR      =  65,  -- opponent clone's yaw (positive = turned left)

    -- territory: the divider slides toward whoever is losing ground
    balance       = 0.5,   -- 0.5 = even split; higher = you own more screen
    targetBalance = 0.5,
    claimGain     = 0.055, -- how much screen one pose claims
    recentre      = 0.45,  -- how fast territory drifts back to even
    slideSpeed    = 5,     -- divider / pane lerp speed
    riseAmount    = 0.9,   -- studs the claiming character lifts
    intro         = 0,     -- 0..1 fade-in so the divider doesn't pop
    loopMirrored  = true,  -- keep mirrored animations looping instead of ending
    gui = nil, L = nil, R = nil, conn = nil,
}

local Chaos = {
    enabled     = false,
    beatSync    = true,

    -- user-facing intensity (0..2 each)
    master      = 1,
    shake       = 1,
    zoomPunch   = 1,
    warp        = 1,
    glitch      = 1,
    flash       = 1,
    readability = 1,   -- lower = camera allowed to swing further off the character

    -- spring state (punch-in -> overshoot -> snap back)
    zoomPos = 0, zoomVel = 0,
    dollyPos = 0, dollyVel = 0,
    rollPos = 0, rollVel = 0,

    -- transient kicks / envelopes
    kickX = 0, kickY = 0,
    impact = 0, rgbSplit = 0, ccSpike = 0,
    warpPhase = 0,

    -- tunnel transition
    tunnelUntil = 0, tunnelDur = 0.9, tunnelFired = false,

    -- glitch bookkeeping
    tearUntil = 0,
    lastHit = 0, hitCount = 0, beatCount = 0,
    beatThread = nil,

    seed = math.random() * 1000,
    gui = nil, cc = nil, layers = {},
}


-- RP / TARGET STATE
local rpModeEnabled   = false   -- was true while its button said OFF
local currentTarget   = nil
local rpMoveStep      = 1.5
local rpMinDistance   = 3.5
local rpRetreatStep   = 1.2
local rpMaxDistance   = 25.0
local targetAnimConn      = nil
local targetCharAddedConn = nil

-- PROXIMITY BLOCK + FIGHTING SYSTEM STATE
local proximityBlockEnabled = true
local proximityBlockDist    = 3.0   -- studs — invisible wall distance
local proximityBlockConn    = nil

local fightModeEnabled    = false
local fightState = {
    active            = false,
    playerMomentum    = 0,
    opponentMomentum  = 0,
    playerHitTimes    = {},
    opponentHitTimes  = {},
    lastPlayerHit     = 0,
    lastOpponentHit   = 0,
    lastPlayerKeys    = {},
    lastPlayerKeyTime = 0,
    pushPerHit        = 0.8,
    pushPerDouble     = 2.0,
    momentumDecay     = 0.92,
    momentumCap       = 12,
    streakWindow      = 1.8,
    doubleNoteWindow  = 0.04,
    idleTimeout       = 2.5,
}
local fightShakeConn   = nil
local fightStatusLbl   = nil

local legsLocked     = false
local savedWalkSpeed = 16
local savedJumpPower = 50

local faceDecal     = nil
local defaultFaceId = nil
local faceIds = { LEFT = "", DOWN = "", UP = "", RIGHT = "" }

local sequence     = {}
local seqPlaying   = false
local seqTrack     = nil
local seqRowFrames = {}

local arrowHudFrames = {}

local idleBPM  = 100
local BASE_BPM = 58

local StatusState = {
    currentAnimName = "—",
    currentAnimId   = "",
    speedMult       = 1,
    bpm             = idleBPM,
    playing         = false,
}

local favorites = {
    { name = "Default: Dance",  id = "507771019" },
    { name = "Default: Dance2", id = "507776043" },
    { name = "Default: Dance3", id = "507777268" },
    { name = "Default: Laugh",  id = "507770818" },
    { name = "Default: Cheer",  id = "507770677" },
    { name = "Default: Point",  id = "507770453" },
    { name = "Default: Sit",    id = "2506281703" },
}
local recents       = {}
local RECENTS_CAP   = 8
local playlist      = {}
local playlistIndex = 1
local playlistPlaying = false

local previewClone     = nil
local previewAnimator  = nil
local previewCam       = nil
local previewAngle     = 0
local previewCloneContainer = nil

local THEMES = {
    Pink   = { accent = Color3.fromRGB(255, 80, 180), accent2 = Color3.fromRGB(0, 200, 255) },
    Cyan   = { accent = Color3.fromRGB(0, 200, 255),  accent2 = Color3.fromRGB(255, 80, 180) },
    Purple = { accent = Color3.fromRGB(165, 85, 255), accent2 = Color3.fromRGB(255, 80, 180) },
    RGB    = { accent = Color3.fromRGB(255, 0, 0),    accent2 = Color3.fromRGB(0, 255, 255) },
    Mono   = { accent = Color3.fromRGB(255, 255, 255), accent2 = Color3.fromRGB(190, 190, 200) },
}
local currentThemeName = "Pink"
local themedStrokes = {}
local themedBgs     = {}
local themedTexts   = {}
local rgbCycleOn    = false

local vinylImage       = nil
local VINYL_DECAL_ID   = ""
local vinylRotation    = 0
local vinylBaseRPM     = 33.3

local crtEnabled  = false
local crtOverlay  = nil

local micDeviceInput = nil
local micAnalyzer    = nil
local micWire        = nil
local micAvailable    = false
local specBars        = {}
local SPEC_BAR_COUNT   = 20

local bpmDetectTaps     = {}
local BPM_TAP_WINDOW    = 8
local detectedBPM       = nil
local beatsPerIdleLoop  = 4

local musicRemote       = nil
local MUSIC_SOUND_NAME  = "FNFMusicPlayer"
local musicStatusLbl    = nil
local musicRequestTick  = 0

local PRIORITY     = Enum.AnimationPriority.Action
local FRAME_TARGET = 10
local BLEND_IN     = 0
local BLEND_OUT    = 0.05

local ARROW_COLORS = {
    LEFT  = { idle = Color3.fromRGB(150, 50, 130), hit = Color3.fromRGB(255, 110, 230) },
    DOWN  = { idle = Color3.fromRGB(0,  130, 170), hit = Color3.fromRGB(0,   240, 255) },
    UP    = { idle = Color3.fromRGB(15, 130,  10), hit = Color3.fromRGB(20,  250,   5) },
    RIGHT = { idle = Color3.fromRGB(160, 35,  35), hit = Color3.fromRGB(255,  90,  90) },
}
local ARROW_SYMBOLS = { LEFT = "◄", DOWN = "▼", UP = "▲", RIGHT = "►" }

local ARROW_SIZE     = 64
local ARROW_HIT_SIZE = 74
local ARROW_GAP      = 14
local ARROW_ORDER    = { "LEFT", "DOWN", "UP", "RIGHT" }

-- ============================================================
--  LOGGING
-- ============================================================
function F.log(m) print("[FNF] "..tostring(m)) end

-- ============================================================
--  CAMERA SYSTEM
-- ============================================================
local CAM_CFG = {
    BaseFOV              = 70,
    MaxZoomFOV           = 54,
    Distance             = 14,
    Height               = 5,
    LookHeight           = 3,
    FollowSmooth         = 7,
    FocusBiasSmooth      = 5,
    ShakeMaxMagnitude    = 0.55,
    ShakeMaxRotDeg       = 1.6,
    LetterboxMaxSize     = 0.09,
    IntensityWindow      = 2.2,
    IntensityHitsForMax  = 9,
    GraceBothActive      = 0.18,
    ReturnToCenterAfter  = 0.9,
    BarsEnabled          = true,   -- cinematic letterbox bars on/off
    NudgeStrength        = 2.5,
    NudgeVertical        = 1.2,
    NudgeDecay           = 3.5,
    NudgeTilt            = 2.5,
    HitFOVPunch          = 2.0,
    HitFOVRecovery       = 8,
}

local CameraSystem = {}
CameraSystem.__index = CameraSystem

function CameraSystem.new()
    local self = setmetatable({}, CameraSystem)

    self.enabled       = false
    self.playerChar    = nil
    self.opponentChar  = nil

    self.focusBias      = 0.5
    self.targetBias     = 0.5

    self.lastPlayerHit    = 0
    self.lastOpponentHit  = 0
    self.hitTimestamps    = {}

    self.intensity        = 0
    self.targetIntensity  = 0
    self.sensitivity      = 1
    self.shakeScale       = 1
    self.zoomScale        = 1

    self.currentCFrame    = nil
    self.currentFOV       = CAM_CFG.BaseFOV
    self.shakeSeed        = math.random() * 1000

    self.nudgeOffset      = Vector3.new(0, 0, 0)
    self.targetNudge      = Vector3.new(0, 0, 0)
    self.nudgeTilt        = 0
    self.targetTilt       = 0
    self.fovPunch         = 0

    self.camDistance      = CAM_CFG.Distance
    self.camHeight        = CAM_CFG.Height
    self.camHorizontal    = 0
    self.camAngle         = 0
    self.camFlipped       = false
    self.soloBlend        = 0

    -- preset / cinematic upgrades
    self.preset        = "Classic"
    self.orbitSpeed    = 0      -- how fast the sweep travels
    self.orbitAmp      = 0      -- degrees the camera arcs around the pair
    self.orbitPhase    = 0
    self.dutch         = 0      -- constant roll, in degrees
    self.handheld      = 0      -- always-on operator drift
    self.lead          = 0      -- camera leans toward whoever is singing
    self.mode          = "STATIC"   -- STATIC / OTS / CUTS / PUSH / CRANE / FP / DIR
    self.dirBoost      = 3.2        -- how hard DIR mode throws the frame per note
    self.dirHold       = 1.4        -- lower = the kick lingers longer

    -- upgraded follow
    -- hit reactions (the camera update)
    self.snapHits      = false      -- kicks land instantly, after smoothing
    self.nudgeScale    = 1          -- how far a note throws the frame
    self.tiltScale     = 1          -- how much LEFT/RIGHT roll the frame
    self.punchScale    = 1          -- FOV dip per hit
    self.returnSpeed   = 1          -- how fast the frame springs home

    self.rideShake     = 0          -- 0..1, fed by Ride from platform speed
    self.rideFov       = 0          -- extra FOV at speed
    self.rideLean      = 0          -- roll, in degrees, under lateral g

    self.beatZoom      = false      -- pulse the lens on every beat
    self.beatPower     = 14         -- FOV dip per beat
    self.beatAccent    = 1.7        -- downbeat multiplier (every 4th)
    self.bzZoom        = 0          -- beat zoom spring
    self.bzVel         = 0
    self.beatThread    = nil
    self.beatCount     = 0

    self.dnZoom        = 0          -- double-note zoom, in FOV degrees
    self.dnZoomVel     = 0
    self.dnPower       = 52         -- how hard a double note dives the lens

    self.springFollow  = true       -- critically damped position spring
    self.springStiff   = 9
    self.camVel        = Vector3.new(0, 0, 0)
    self.leadTime      = 0.18       -- anticipates where the characters are heading
    self.autoFrame     = true       -- widens the shot as they separate
    self.pitchBias     = 0          -- raises the look target (low-angle hero framing)
    self.pushAmt       = 0          -- dolly-in progress, 0..1
    self.cranePhase    = 0
    self.lastCutSubject = nil
    self.lastCutTime   = 0
    self.settleEnabled = false
    self.settleAfter   = 1.6    -- seconds of silence before the camera locks
    self.settled       = false

    self.conn             = nil
    self.letterTop        = nil
    self.letterBottom     = nil
    self.statusCb         = nil

    return self
end

-- Real shot grammar, not a permanent orbit. Each preset is a technique
-- you'd actually see in a film or a cutscene.
local CAM_PRESETS = {
    ["Two Shot"] = {
        mode = "STATIC", camDistance = 13, camHeight = 4.5, fov = 68,
        orbitSpeed = 0, orbitAmp = 0, dutch = 0, handheld = 0,
        lead = 0.5, pitchBias = 0, settleAfter = 1.2,
        desc = "Locked wide holding both of you. The default coverage shot.",
    },
    ["Over Shoulder"] = {
        mode = "OTS", camDistance = 9, camHeight = 3.4, fov = 62,
        orbitSpeed = 0, orbitAmp = 0, dutch = 0, handheld = 0.18,
        lead = 0.3, pitchBias = 0.4, settleAfter = 1.6,
        desc = "Sits behind the listener's shoulder, framed on whoever is singing.",
    },
    ["Shot / Reverse"] = {
        mode = "CUTS", camDistance = 6, camHeight = 3.2, fov = 55,
        orbitSpeed = 0, orbitAmp = 0, dutch = 0, handheld = 0.22,
        lead = 0, pitchBias = 0.5, settleAfter = 1.8,
        desc = "Hard cuts between close-ups as the line passes back and forth.",
    },
    ["Slow Push"] = {
        mode = "PUSH", camDistance = 14, camHeight = 4.8, fov = 66,
        orbitSpeed = 0, orbitAmp = 0, dutch = 0, handheld = 0.1,
        lead = 0.7, pitchBias = 0, settleAfter = 2.2,
        desc = "Creeps in through the phrase, drifts back out when it ends.",
    },
    ["Low Hero"] = {
        mode = "STATIC", camDistance = 9, camHeight = 1.1, fov = 62,
        orbitSpeed = 0, orbitAmp = 0, dutch = 2, handheld = 0.12,
        lead = 0.6, pitchBias = 2.6, settleAfter = 1.4,
        desc = "Camera on the floor looking up. Makes you look enormous.",
    },
    Crane = {
        mode = "CRANE", camDistance = 15, camHeight = 6, fov = 70,
        orbitSpeed = 0, orbitAmp = 0, dutch = 0, handheld = 0,
        lead = 0.6, pitchBias = 0, settleAfter = 2.5,
        desc = "Slow vertical jib. Rises and falls, never spins.",
    },
    Directional = {
        mode = "DIR", camDistance = 11, camHeight = 4, fov = 72,
        orbitSpeed = 0, orbitAmp = 0, dutch = 0, handheld = 0.15,
        lead = 0.5, pitchBias = 0.3, settleAfter = 1.5,
        desc = "The frame kicks the way each note points, then eases home.",
    },
    Snappy = {
        mode = "SNAP", camDistance = 11, camHeight = 4.2, fov = 70,
        orbitSpeed = 0, orbitAmp = 0, dutch = 0, handheld = 0.1,
        lead = 0.5, pitchBias = 0.2, settleAfter = 1.4,
        dirBoost = 2.4, dirHold = 2.6, snapHits = true,
        desc = "Every note snaps the frame the way it points, then springs straight back.",
    },
    ["First Person"] = {
        mode = "FP", camDistance = 0, camHeight = 0, fov = 82,
        orbitSpeed = 0, orbitAmp = 0, dutch = 0, handheld = 0.5,
        lead = 0, pitchBias = 0, settleAfter = 6,
        desc = "Straight out of your own eyes, locked on your opponent.",
    },
}
local CAM_PRESET_ORDER = { "Two Shot", "Over Shoulder", "Shot / Reverse",
                           "Slow Push", "Low Hero", "Crane", "Directional", "Snappy", "First Person" }

function CameraSystem:ApplyPreset(name)
    local p = CAM_PRESETS[name]
    if not p then return end
    self.preset      = name
    self.mode        = p.mode
    self.pitchBias   = p.pitchBias
    self.pushAmt     = 0
    self.camDistance = p.camDistance
    self.camHeight   = p.camHeight
    self.orbitSpeed  = p.orbitSpeed
    self.orbitAmp    = p.orbitAmp
    self.dutch       = p.dutch
    self.handheld    = p.handheld
    self.lead        = p.lead
    self.settleAfter = p.settleAfter
    CAM_CFG.BaseFOV  = p.fov
    if p.dirBoost then self.dirBoost = p.dirBoost end
    if p.dirHold then self.dirHold = p.dirHold end
    if p.snapHits ~= nil then self.snapHits = p.snapHits end
    self.currentCFrame = nil   -- cut cleanly into the new shot
    self.settled     = false
end

function CameraSystem:BuildLetterbox(playerGui)
    local sg = playerGui:FindFirstChild("FNFCameraFX")
    if sg then sg:Destroy() end
    sg = F.own(Instance.new("ScreenGui"))
    sg.Name = "FNFCameraFX"
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 50
    sg.ResetOnSpawn = false
    sg.Parent = playerGui

    local top = Instance.new("Frame")
    top.Name = "LetterboxTop"
    top.BackgroundColor3 = Color3.new(0, 0, 0)
    top.BorderSizePixel = 0
    top.Size = UDim2.new(1, 0, 0, 0)
    top.Position = UDim2.new(0, 0, 0, 0)
    top.ZIndex = 100
    top.Parent = sg

    local bottom = Instance.new("Frame")
    bottom.Name = "LetterboxBottom"
    bottom.BackgroundColor3 = Color3.new(0, 0, 0)
    bottom.BorderSizePixel = 0
    bottom.Size = UDim2.new(1, 0, 0, 0)
    bottom.AnchorPoint = Vector2.new(0, 1)
    bottom.Position = UDim2.new(0, 0, 1, 0)
    bottom.ZIndex = 100
    bottom.Parent = sg

    self.letterTop, self.letterBottom = top, bottom
end

function CameraSystem:SetPlayerCharacter(char) self.playerChar = char end

function CameraSystem:SetOpponentCharacter(char)
    self.opponentChar = char
    if not char then self.targetBias = 0 end
end

function CameraSystem:SetSensitivity(mult) self.sensitivity = math.clamp(mult, 0.25, 3) end
function CameraSystem:SetShakeScale(pct01) self.shakeScale = math.clamp(pct01, 0, 1) end
function CameraSystem:SetZoomScale(pct01) self.zoomScale = math.clamp(pct01, 0, 1) end

function CameraSystem:RegisterHit(who)
    local now = os.clock()
    Split.claim(who)
    Health.onHit(who)
    if who == "OPPONENT" then pcall(F.oppReact) end
    table.insert(self.hitTimestamps, now)
    if who == "PLAYER" then
        self.lastPlayerHit = now
    elseif who == "OPPONENT" then
        self.lastOpponentHit = now
        if Cam2.oppZoom then Cam2.oppAmt = Cam2.oppZoomPower; self.settled = false end
    end
end

function CameraSystem:RegisterDirectionalHit(dir)
    if not self.enabled then return end
    local boost = (self.mode == "DIR" or self.mode == "SNAP") and self.dirBoost or 1
    local s = CAM_CFG.NudgeStrength * boost * self.nudgeScale
    local v = CAM_CFG.NudgeVertical * boost * self.nudgeScale
    local tilt = CAM_CFG.NudgeTilt * boost * self.tiltScale
    if dir == "LEFT" then
        self.targetNudge = Vector3.new(-s, 0, 0)
        self.targetTilt = math.rad(tilt)
    elseif dir == "RIGHT" then
        self.targetNudge = Vector3.new(s, 0, 0)
        self.targetTilt = math.rad(-tilt)
    elseif dir == "UP" then
        self.targetNudge = Vector3.new(0, v, 0)
        self.targetTilt = 0
    elseif dir == "DOWN" then
        self.targetNudge = Vector3.new(0, -v, 0)
        self.targetTilt = 0
    end
    self.fovPunch = CAM_CFG.HitFOVPunch * boost * self.punchScale
    if self.snapHits then
        -- no ease-in: the frame is AT the kick on the same frame you press
        self.nudgeOffset = self.targetNudge
        self.nudgeTilt = self.targetTilt
    end
    self.settled = false
    if Cam2.dirShake then
        local sideways = (dir == "LEFT" or dir == "RIGHT")
        local sign = (dir == "LEFT" or dir == "DOWN") and -1 or 1
        Cam2.kick(sideways and Vector2.new(sign, 0) or Vector2.new(0, sign), Cam2.dirShakePower)
    end
    Chaos.hit(1, dir)
end

-- Hard lens dive on a double note. Independent of Chaos, so it fires
-- even with the chaos camera switched off.
function CameraSystem:DoubleNoteZoom(power)
    if not self.enabled then return end
    power = power or 1
    self.dnZoomVel = self.dnZoomVel - self.dnPower * power
    self.settled = false
end

-- Pulses the lens in time with the current BPM. Reads StatusState.bpm each
-- beat, so changing tempo retimes it without restarting anything.
function CameraSystem:SetBeatZoom(state)
    self.beatZoom = state
    if state and not self.beatThread then
        self.beatThread = task.spawn(function()
            while self.beatZoom do
                local bpm = math.max(40, StatusState.bpm or 100)
                task.wait(60 / bpm)
                if not self.beatZoom then break end
                self.beatCount = (self.beatCount + 1) % 4
                local accent = (self.beatCount == 0) and self.beatAccent or 1
                Cam2.beatN = Cam2.beatN + 1
                if Cam2.beatN % math.max(1, math.floor(Cam2.pulseEvery + 0.5)) == 0 then
                    self.bzVel = self.bzVel - self.beatPower * accent
                    if Cam2.beatShake > 0 then Cam2.kick(Vector2.new(0, 1), Cam2.beatShake * accent) end
                end
                self.settled = false
            end
            self.beatThread = nil
        end)
    end
    if not state then
        self.bzZoom, self.bzVel = 0, 0
    end
end

function CameraSystem:_recomputeIntensity(now)
    for i = #self.hitTimestamps, 1, -1 do
        if now - self.hitTimestamps[i] > CAM_CFG.IntensityWindow then
            table.remove(self.hitTimestamps, i)
        end
    end
    local hitsForMax = math.max(2, CAM_CFG.IntensityHitsForMax / self.sensitivity)
    self.targetIntensity = math.clamp(#self.hitTimestamps / hitsForMax, 0, 1)
end

function CameraSystem:_updateLetterbox()
    if not self.letterTop or not self.letterBottom then return end
    local frac = CAM_CFG.BarsEnabled and (CAM_CFG.LetterboxMaxSize * self.intensity) or 0
    self.letterTop.Size = UDim2.new(1, 0, frac, 0)
    self.letterBottom.Size = UDim2.new(1, 0, frac, 0)
end

function CameraSystem:_update(dt)
    if not self.enabled then return end
    local cam = Workspace.CurrentCamera
    if not cam then return end

    local pRoot = self.playerChar and self.playerChar:FindFirstChild("HumanoidRootPart")
    if not pRoot then return end
    local oRoot = self.opponentChar and self.opponentChar:FindFirstChild("HumanoidRootPart")

    local now = os.clock()
    local recentP = (now - self.lastPlayerHit) < CAM_CFG.GraceBothActive
    local recentO = (now - self.lastOpponentHit) < CAM_CFG.GraceBothActive
    local silentFor = math.min(now - self.lastPlayerHit, now - self.lastOpponentHit)

    -- Once both sides stop and the shake has died out, freeze exactly where
    -- we are. No drift, no noise, no re-framing until someone hits again.
    local quietFor = now - math.max(self.lastPlayerHit, self.lastOpponentHit)
    if self.settleEnabled and self.currentCFrame and not soloActive and not Boss.active and not Cam2.shot
        and quietFor > self.settleAfter and self.intensity < 0.03
        and self.rideShake < 0.02 then
        if not self.settled then
            self.settled = true
            self.targetNudge = Vector3.new(0, 0, 0)
            self.targetTilt = 0
        end
        cam.CFrame = self.currentCFrame
        cam.FieldOfView = self.currentFOV
        if self.letterTop then self.letterTop.Size = UDim2.new(1, 0, 0, 0) end
        if self.letterBottom then self.letterBottom.Size = UDim2.new(1, 0, 0, 0) end
        if self.statusCb then self.statusCb("SETTLED", 0) end
        return
    end
    self.settled = false

    if oRoot then
        if recentP and recentO then
            self.targetBias = 0.5
        elseif recentP then
            self.targetBias = 0.0
        elseif recentO then
            self.targetBias = 1.0
        elseif silentFor > CAM_CFG.ReturnToCenterAfter then
            self.targetBias = 0.5
        end
    else
        self.targetBias = 0.0
    end

    local biasAlpha = 1 - math.exp(-CAM_CFG.FocusBiasSmooth * dt)
    self.focusBias = self.focusBias + (self.targetBias - self.focusBias) * biasAlpha

    local playerPos = pRoot.Position
    local oppPos = oRoot and oRoot.Position or playerPos
    -- lead the framing by where each character is actually heading, so the
    -- camera stops trailing behind fast movement
    local leadP, leadO = Vector3.new(), Vector3.new()
    if self.leadTime > 0 then
        local pv = pRoot.AssemblyLinearVelocity
        leadP = Vector3.new(pv.X, 0, pv.Z) * self.leadTime
        if leadP.Magnitude > 6 then leadP = leadP.Unit * 6 end
        if oRoot then
            local ov = oRoot.AssemblyLinearVelocity
            leadO = Vector3.new(ov.X, 0, ov.Z) * self.leadTime
            if leadO.Magnitude > 6 then leadO = leadO.Unit * 6 end
        end
    end
    local focusPoint = (playerPos + leadP):Lerp(oppPos + leadO, self.focusBias)
        + Vector3.new(0, CAM_CFG.LookHeight, 0)

    local axis
    if oRoot then
        local flat = Vector3.new(oppPos.X - playerPos.X, 0, oppPos.Z - playerPos.Z)
        if flat.Magnitude > 1e-3 then
            axis = Vector3.new(-flat.Unit.Z, 0, flat.Unit.X)
        end
    end
    if not axis then
        axis = pRoot.CFrame.LookVector * -1
    end

    if self.camFlipped then
        axis = -axis
    end

    if self.camAngle ~= 0 then
        local rad = math.rad(self.camAngle)
        local cosA, sinA = math.cos(rad), math.sin(rad)
        axis = Vector3.new(axis.X * cosA - axis.Z * sinA, 0, axis.X * sinA + axis.Z * cosA).Unit
    end

    -- orbit sweep: arcs the camera around the pair, faster while it's hot
    if self.orbitAmp > 0 then
        self.orbitPhase = self.orbitPhase + dt * self.orbitSpeed * (0.4 + self.intensity * 1.7)
        local sweep = math.sin(self.orbitPhase) * math.rad(self.orbitAmp)
        local cs, sn = math.cos(sweep), math.sin(sweep)
        axis = Vector3.new(axis.X * cs - axis.Z * sn, 0, axis.X * sn + axis.Z * cs).Unit
    end

    -- lead: lean the framing toward whoever is singing
    if self.lead > 0 and oRoot then
        local leanDir = (oppPos - playerPos)
        leanDir = Vector3.new(leanDir.X, 0, leanDir.Z)
        if leanDir.Magnitude > 1e-3 then
            focusPoint = focusPoint + leanDir.Unit * ((self.focusBias - 0.5) * 2 * self.lead)
        end
    end

    local separation = oRoot and (playerPos - oppPos).Magnitude or 0
    local dynamicDistance = (self.camDistance + separation * 0.18) * Cam2.distMul()
    local autoHeight = self.camHeight
    if self.autoFrame then
        -- rise a little as they spread out so both stay comfortably in frame
        autoHeight = autoHeight + math.clamp(separation * 0.06, 0, 3)
    end
    local desiredPos = focusPoint + axis * dynamicDistance + Vector3.new(0, autoHeight, 0)

    if self.camHorizontal ~= 0 then
        local slideDir = Vector3.new(0, 1, 0):Cross(axis)
        if slideDir.Magnitude > 1e-3 then
            desiredPos = desiredPos + slideDir.Unit * self.camHorizontal
        end
    end

    -- raise the look target for low-angle framing
    focusPoint = focusPoint + Vector3.new(0, self.pitchBias, 0)

    -- ---- boss cutscene overrides everything ----
    local mode = self.mode
    if Boss.active and oRoot then
        local toOpp = Vector3.new(oppPos.X - playerPos.X, 0, oppPos.Z - playerPos.Z)
        local dir = (toOpp.Magnitude > 1e-3) and toOpp.Unit or pRoot.CFrame.LookVector
        desiredPos = playerPos - dir * Boss.dist + Vector3.new(0, Boss.height, 0)
        local desiredCF = CFrame.new(desiredPos, oppPos + Vector3.new(0, Boss.lookHeight, 0))
        if not self.currentCFrame then self.currentCFrame = desiredCF end
        self.currentCFrame = self.currentCFrame:Lerp(desiredCF, 1 - math.exp(-4 * dt))
        self.currentFOV = self.currentFOV + (64 - self.currentFOV) * (1 - math.exp(-4 * dt))
        if self.letterTop then self.letterTop.Size = UDim2.new(1, 0, Boss.bars, 0) end
        if self.letterBottom then self.letterBottom.Size = UDim2.new(1, 0, Boss.bars, 0) end
        local bcf, bfov = self.currentCFrame, self.currentFOV
        if Chaos.enabled then bcf, bfov = Chaos.apply(bcf, bfov, dt) end
        cam.CFrame = bcf; cam.FieldOfView = bfov
        if self.statusCb then self.statusCb("BOSS", self.intensity) end
        return
    end

    -- ---- shot grammar ----
    local subjectPos, subjectCF, otherPos
    if self.focusBias > 0.5 and oRoot then
        subjectPos, subjectCF, otherPos = oppPos, oRoot.CFrame, playerPos
    else
        subjectPos, subjectCF, otherPos = playerPos, pRoot.CFrame, (oRoot and oppPos or playerPos)
    end

    if mode == "PUSH" then
        -- creeps in while someone is singing, eases back out when quiet
        local wantPush = (silentFor < 0.7) and 1 or 0
        self.pushAmt = self.pushAmt + (wantPush - self.pushAmt) * (1 - math.exp(-1.6 * dt))
        dynamicDistance = dynamicDistance * (1 - 0.3 * self.pushAmt)
        desiredPos = focusPoint + axis * dynamicDistance + Vector3.new(0, autoHeight, 0)

    elseif mode == "CRANE" then
        self.cranePhase = self.cranePhase + dt * 0.28
        local lift = math.sin(self.cranePhase) * 3.2
        desiredPos = focusPoint + axis * dynamicDistance + Vector3.new(0, autoHeight + lift, 0)

    elseif mode == "OTS" and oRoot then
        -- behind the listener's shoulder, framed past them onto the singer
        local otherRoot = (subjectPos == oppPos) and pRoot or oRoot
        local ocf = otherRoot.CFrame
        desiredPos = ocf.Position
            - ocf.LookVector * 2.4
            + ocf.RightVector * 1.7
            + Vector3.new(0, 2.7, 0)
        focusPoint = subjectPos + Vector3.new(0, 2.2 + self.pitchBias, 0)

    elseif mode == "CUTS" then
        -- close-up in front of whoever is singing; hard cut when it flips
        local key = (subjectPos == oppPos) and "OPP" or "PLR"
        if key ~= self.lastCutSubject and (now - self.lastCutTime) > 0.35 then
            self.lastCutSubject = key
            self.lastCutTime = now
            self.currentCFrame = nil     -- nil forces an instant cut, not a pan
            self.camVel = Vector3.new(0, 0, 0)
        end
        desiredPos = subjectPos
            + subjectCF.LookVector * self.camDistance
            + subjectCF.RightVector * 1.4
            + Vector3.new(0, self.camHeight, 0)
        focusPoint = subjectPos + Vector3.new(0, 2.3 + self.pitchBias, 0)

    elseif mode == "FP" then
        local head = self.playerChar and self.playerChar:FindFirstChild("Head")
        local eye = head and head.CFrame or (pRoot.CFrame + Vector3.new(0, 1.6, 0))
        desiredPos = eye.Position + eye.LookVector * 0.35
        focusPoint = oRoot and (oppPos + Vector3.new(0, 2.2 + self.pitchBias, 0))
            or (desiredPos + eye.LookVector * 12)
    end

    local desiredCFrame = CFrame.new(desiredPos, focusPoint)

    local soloTarget = soloActive and 1 or 0
    local soloAlpha = 1 - math.exp(-3 / math.max(soloTransition, 0.1) * dt)
    self.soloBlend = self.soloBlend + (soloTarget - self.soloBlend) * soloAlpha

    if self.soloBlend > 0.001 then
        local soloFocus = playerPos + Vector3.new(0, CAM_CFG.LookHeight + 0.5, 0)
        local soloAxis = pRoot.CFrame.LookVector
        local soloPos = soloFocus - soloAxis * soloCamDist + Vector3.new(0, soloCamHeight, 0)
        local soloCFrame = CFrame.new(soloPos, soloFocus)
        desiredCFrame = desiredCFrame:Lerp(soloCFrame, self.soloBlend)
    end

    if self.letterTop and self.letterBottom then
        local normalBar = CAM_CFG.LetterboxMaxSize * self.intensity
        local soloBar = soloLetterbox * self.soloBlend
        local barSize = CAM_CFG.BarsEnabled and math.max(normalBar, soloBar) or 0
        self.letterTop.Size = UDim2.new(1, 0, barSize, 0)
        self.letterBottom.Size = UDim2.new(1, 0, barSize, 0)
    end

    self:_recomputeIntensity(now)
    local intensityAlpha = 1 - math.exp(-3 * dt)
    self.intensity = self.intensity + (self.targetIntensity - self.intensity) * intensityAlpha

    local shakeMag = CAM_CFG.ShakeMaxMagnitude * self.shakeScale * self.intensity
    local shakeRot = CAM_CFG.ShakeMaxRotDeg * self.shakeScale * self.intensity
    -- riding a fast platform adds its own rattle on top, at a higher frequency
    shakeMag = shakeMag + self.rideShake * 0.9
    shakeRot = shakeRot + self.rideShake * 2.2
    local t = now * (14 + self.rideShake * 26)
    local shakeOffset = Vector3.new(
        (math.noise(t, self.shakeSeed) - 0.5) * 2 * shakeMag,
        (math.noise(t, self.shakeSeed + 30) - 0.5) * 2 * shakeMag,
        0
    )
    local shakeYaw = math.rad((math.noise(t, self.shakeSeed + 60) - 0.5) * 2 * shakeRot)
    local shakePitch = math.rad((math.noise(t, self.shakeSeed + 90) - 0.5) * 2 * shakeRot)

    local holdMul = ((self.mode == "DIR" or self.mode == "SNAP") and self.dirHold or 1) * self.returnSpeed
    local decayRate = CAM_CFG.NudgeDecay * holdMul
    local nudgeAlpha = 1 - math.exp(-decayRate * dt)
    if self.snapHits then
        -- already at full kick from the hit itself, so just return home
        local k = math.exp(-decayRate * 1.6 * dt)
        self.nudgeOffset = self.nudgeOffset * k
        self.nudgeTilt = self.nudgeTilt * k
        self.targetNudge = Vector3.new(0, 0, 0)
        self.targetTilt = 0
    else
        self.nudgeOffset = self.nudgeOffset:Lerp(self.targetNudge, nudgeAlpha)
        self.nudgeTilt = self.nudgeTilt + (self.targetTilt - self.nudgeTilt) * nudgeAlpha
        self.targetNudge = self.targetNudge:Lerp(Vector3.new(0,0,0), nudgeAlpha * 0.7)
        self.targetTilt = self.targetTilt + (0 - self.targetTilt) * nudgeAlpha * 0.7
    end

    self.fovPunch = self.fovPunch + (0 - self.fovPunch)
        * (1 - math.exp(-CAM_CFG.HitFOVRecovery * self.returnSpeed * dt))

    local camRight = desiredCFrame.RightVector
    local camUp = desiredCFrame.UpVector
    local nudgeWorld = camRight * self.nudgeOffset.X + camUp * self.nudgeOffset.Y

    -- constant operator drift, independent of hit intensity
    if self.handheld > 0 then
        local ht = now * 0.85
        shakeOffset = shakeOffset + Vector3.new(
            math.noise(ht, self.shakeSeed + 200) * self.handheld * 0.55,
            math.noise(ht, self.shakeSeed + 260) * self.handheld * 0.4,
            0)
        shakePitch = shakePitch + math.rad(math.noise(ht, self.shakeSeed + 320) * self.handheld * 1.2)
        shakeYaw = shakeYaw + math.rad(math.noise(ht, self.shakeSeed + 380) * self.handheld * 1.2)
    end

    local dutchRoll = math.rad(self.dutch) * (0.5 + self.intensity * 0.5) + math.rad(self.rideLean)
    -- The follow spring below smooths anything added here. That's right for
    -- framing, but it's why hits used to feel mushy: the kick got eased in.
    -- Snappy hits skip this and are applied after smoothing instead.
    local preNudge = self.snapHits and Vector3.new(0, 0, 0) or nudgeWorld
    local preTilt = self.snapHits and 0 or self.nudgeTilt
    desiredCFrame = desiredCFrame * CFrame.new(shakeOffset + preNudge) * CFrame.Angles(shakePitch, shakeYaw, preTilt + dutchRoll)

    if not self.currentCFrame then
        self.currentCFrame = desiredCFrame
        self.camVel = Vector3.new(0, 0, 0)
    end
    local followAlpha = 1 - math.exp(-CAM_CFG.FollowSmooth * dt)

    if self.springFollow then
        -- Critically damped spring on position: catches up fast without the
        -- rubber-banding a plain lerp gives you at low frame rates.
        local cur = self.currentCFrame.Position
        local w = self.springStiff
        local accel = (desiredCFrame.Position - cur) * (w * w) - self.camVel * (2 * w)
        self.camVel = self.camVel + accel * dt
        local newPos = cur + self.camVel * dt
        -- rotation still eases, so the aim never jitters
        local rot = self.currentCFrame:Lerp(desiredCFrame, followAlpha)
        self.currentCFrame = CFrame.new(newPos) * (rot - rot.Position)
    else
        self.currentCFrame = self.currentCFrame:Lerp(desiredCFrame, followAlpha)
    end

    local zoomAmount = (CAM_CFG.BaseFOV - CAM_CFG.MaxZoomFOV) * self.zoomScale * self.intensity
    local normalFOV = CAM_CFG.BaseFOV - zoomAmount - (self.snapHits and 0 or self.fovPunch)
    -- double-note zoom spring: dives in fast, springs back out
    self.dnZoomVel = self.dnZoomVel + (-150 * self.dnZoom - 14 * self.dnZoomVel) * dt
    self.dnZoom = self.dnZoom + self.dnZoomVel * dt
    normalFOV = normalFOV + self.dnZoom

    -- beat zoom: softer spring so it breathes instead of snapping
    self.bzVel = self.bzVel + (-95 * self.bzZoom - 13 * self.bzVel) * dt
    self.bzZoom = self.bzZoom + self.bzVel * dt
    normalFOV = normalFOV + self.bzZoom

    normalFOV = normalFOV + self.rideFov

    if self.autoFrame then
        normalFOV = normalFOV + math.clamp(separation * 0.25, 0, 8)
    end
    local targetFOV = normalFOV + (soloCamFOV - normalFOV) * self.soloBlend
    targetFOV = math.clamp(targetFOV, 15, 120)
    self.currentFOV = self.currentFOV + (targetFOV - self.currentFOV) * followAlpha

    local finalCF, finalFOV = self.currentCFrame, self.currentFOV
    finalCF, finalFOV = Cam2.post(finalCF, finalFOV, dt)
    if self.snapHits then
        -- hits land on top of the smoothed frame, untouched by the follow spring
        finalCF = finalCF
            * CFrame.new(self.nudgeOffset.X, self.nudgeOffset.Y, 0)
            * CFrame.Angles(0, 0, self.nudgeTilt)
        finalFOV = finalFOV - self.fovPunch
    end
    if Chaos.enabled then
        finalCF, finalFOV = Chaos.apply(finalCF, finalFOV, dt)
    end
    cam.CFrame = finalCF
    cam.FieldOfView = finalFOV

    if self.soloBlend <= 0.001 then
        self:_updateLetterbox()
    end

    if self.statusCb then
        local label = self.focusBias < 0.33 and "PLAYER" or (self.focusBias > 0.66 and "OPPONENT" or "CENTER")
        self.statusCb(label, self.intensity)
    end
end

function CameraSystem:SetEnabled(state)
    self.enabled = state
    local cam = Workspace.CurrentCamera
    if state then
        if cam then cam.CameraType = Enum.CameraType.Scriptable end
        self.currentCFrame = nil
    else
        if cam then
            cam.CameraType = Enum.CameraType.Custom
            cam.FieldOfView = CAM_CFG.BaseFOV
        end
        if self.letterTop then self.letterTop.Size = UDim2.new(1, 0, 0, 0) end
        if self.letterBottom then self.letterBottom.Size = UDim2.new(1, 0, 0, 0) end
    end
end

function CameraSystem:Start()
    if self.conn then return end
    self.conn = F.own(RunService.RenderStepped:Connect(function(dt) self:_update(dt) end))
end

function CameraSystem:Destroy()
    if self.conn then self.conn:Disconnect(); self.conn = nil end
    self:SetEnabled(false)
end

local FNFCamera = CameraSystem.new()

-- ============================================================
--  SILHOUETTE MODE — world washes white, fighters go black
--  (all drawn elements clamped to ZIndex/DisplayOrder 200)
-- ============================================================

function Sil.clearOne(char)
    if not char then return end
    local h = Sil.highlights[char]
    if h then pcall(function() h:Destroy() end); Sil.highlights[char] = nil end
end

function Sil.clearAll()
    for char in pairs(Sil.highlights) do Sil.clearOne(char) end
end

function Sil.applyTo(char, alpha)
    if not char or not char.Parent then return end
    local h = Sil.highlights[char]
    if not h or h.Parent ~= char then
        if h then pcall(function() h:Destroy() end) end
        h = F.own(Instance.new("Highlight"))
        h.Name = "FNFSilhouette"
        h.Parent = char
        Sil.highlights[char] = h
    end
    local col = SilFX.fillColor
    if SilFX.splitColors then col = (char == character) and SilFX.playerColor or SilFX.oppColor end
    h.FillColor    = col
    h.OutlineColor = SilFX.outline and SilFX.outlineColor or col
    h.DepthMode    = SilFX.alwaysOnTop
        and Enum.HighlightDepthMode.AlwaysOnTop
        or Enum.HighlightDepthMode.Occluded
    h.FillTransparency    = 1 - alpha * 0.92
    h.OutlineTransparency = 1 - alpha
end

-- Quick white punch when the mode snaps on. Capped at ZIndex 200.
function Sil.flash()
    if Sil.flashGui then Sil.flashGui:Destroy(); Sil.flashGui = nil end
    local sg = F.own(Instance.new("ScreenGui"))
    sg.Name = "FNFSilhouetteFlash"; sg.IgnoreGuiInset = true
    sg.ResetOnSpawn = false; sg.DisplayOrder = F.silZ(150)
    sg.Parent = PlayerGui
    Sil.flashGui = sg

    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 1, 0)
    f.BackgroundColor3 = Color3.new(1, 1, 1)
    f.BackgroundTransparency = 0.3
    f.BorderSizePixel = 0
    f.ZIndex = F.silZ(198)
    f.Parent = sg

    local tw = TweenService:Create(f, TweenInfo.new(0.35, Enum.EasingStyle.Quint), { BackgroundTransparency = 1 })
    tw:Play()
    tw.Completed:Connect(function()
        sg:Destroy()
        if Sil.flashGui == sg then Sil.flashGui = nil end
    end)
end

function Sil.start()
    if Sil.conn then return end

    Sil.cc = F.own(Instance.new("ColorCorrectionEffect"))
    Sil.cc.Name = "FNFSilhouette"
    Sil.cc.Brightness = 0; Sil.cc.Contrast = 0; Sil.cc.Saturation = 0
    Sil.cc.Parent = Lighting

    Sil.blur = F.own(Instance.new("BlurEffect"))
    Sil.blur.Name = "FNFSilhouetteBlur"; Sil.blur.Size = 0
    Sil.blur.Parent = Lighting

    Sil.conn = F.own(RunService.Heartbeat:Connect(function(dt)
        local target = silhouetteActive and 1 or 0
        silhouetteBlend = silhouetteBlend + (target - silhouetteBlend) * (1 - math.exp(-SilFX.fadeSpeed * dt))
        local a = silhouetteBlend * SilFX.strength

        if Sil.cc then
            Sil.cc.Brightness = a * 3
            Sil.cc.Contrast   = a * -0.8
            Sil.cc.Saturation = a * -4
        end
        if Sil.blur then Sil.blur.Size = a * 6 end

        local opp = currentTarget and currentTarget.Character or nil

        if SilFX.includePlayer and character and a > 0.01 then
            Sil.applyTo(character, a)
        else
            Sil.clearOne(character)
        end

        if SilFX.includeOpponent and opp and a > 0.01 then
            Sil.applyTo(opp, a)
        else
            Sil.clearOne(opp)
        end

        -- drop highlights for anyone who respawned / left / got unset
        for char in pairs(Sil.highlights) do
            if not char.Parent or (char ~= character and char ~= opp) then
                Sil.clearOne(char)
            end
        end

        if not silhouetteActive and silhouetteBlend < 0.01 then
            Sil.clearAll()
            if Sil.cc then Sil.cc:Destroy(); Sil.cc = nil end
            if Sil.blur then Sil.blur:Destroy(); Sil.blur = nil end
            if Sil.conn then Sil.conn:Disconnect(); Sil.conn = nil end
        end
    end))
end

function Sil.set(state)
    if state == silhouetteActive then return end
    silhouetteActive = state
    if state then Sil.start(); Sil.flash() end
    if F.refreshSilUI then F.refreshSilUI() end
    if F.notify then
        F.notify(state and "🖤 SILHOUETTE MODE" or "Silhouette off", state and "success" or "info")
    end
end

-- ============================================================
--  SPLIT SCREEN — player left, opponent right
--  Both cameras are locked still. The clones are yawed inward so
--  the two characters face each other across the divider.
-- ============================================================
function Split.makeSide(parent, xScale, title, tint, rotKey)
    local vp = Instance.new("ViewportFrame")
    vp.Size = UDim2.new(0.5, -2, 1, 0)
    vp.Position = UDim2.new(xScale, xScale == 0 and 0 or 2, 0, 0)
    vp.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
    vp.BackgroundTransparency = 0.1
    vp.BorderSizePixel = 0
    vp.Ambient = Color3.fromRGB(150, 150, 160)
    vp.LightColor = Color3.fromRGB(255, 255, 255)
    vp.LightDirection = Vector3.new(-0.4, -1, -0.3)
    vp.ZIndex = F.silZ(120)
    vp.Parent = parent

    local wm = Instance.new("WorldModel"); wm.Parent = vp
    local cam = Instance.new("Camera"); cam.FieldOfView = 55; cam.Parent = vp
    vp.CurrentCamera = cam

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 22); lbl.Position = UDim2.new(0, 0, 1, -30)
    lbl.BackgroundTransparency = 1; lbl.Text = title
    lbl.TextColor3 = tint; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 13
    lbl.ZIndex = F.silZ(126); lbl.Parent = vp

    return { vp = vp, wm = wm, cam = cam, label = lbl, rotKey = rotKey,
             clone = nil, animator = nil, rise = 0, riseVel = 0 }
end

function Split.build()
    local old = PlayerGui:FindFirstChild("FNFSplitScreen")
    if old then old:Destroy() end

    local sg = F.own(Instance.new("ScreenGui"))
    sg.Name = "FNFSplitScreen"; sg.IgnoreGuiInset = true
    sg.ResetOnSpawn = false; sg.DisplayOrder = F.silZ(120)
    sg.Enabled = Split.enabled
    sg.Parent = PlayerGui
    Split.gui = sg

    Split.L = Split.makeSide(sg, 0,   "YOU",      Color3.fromRGB(255, 110, 230), "rotL")
    Split.R = Split.makeSide(sg, 0.5, "OPPONENT", Color3.fromRGB(0, 240, 255),   "rotR")

    local div = Instance.new("Frame")
    div.Size = UDim2.new(0, 4, 1, 0); div.Position = UDim2.new(0.5, -2, 0, 0)
    div.BackgroundColor3 = Color3.fromRGB(255, 80, 180)
    div.BackgroundTransparency = 1          -- fades in, never pops
    div.BorderSizePixel = 0; div.ZIndex = F.silZ(125); div.Parent = sg
    F.regBg(div)
    Split.div = div

    -- start even and let the intro ease everything in
    Split.balance, Split.targetBalance = 0.5, 0.5
    Split.intro = 0

    Split.refreshClones()
end

function Split.loadClone(side, char)
    if not side then return end
    if side.clone then pcall(function() side.clone:Destroy() end) end
    side.clone, side.animator = nil, nil
    if not char or not char.Parent then return end

    local wasArch = char.Archivable
    if not wasArch then char.Archivable = true end
    local ok, clone = pcall(function() return char:Clone() end)
    if not wasArch then char.Archivable = wasArch end
    if not ok or not clone then return end

    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end
    end
    clone.Name = "SplitClone"
    clone.Parent = side.wm

    local hum = clone:FindFirstChildOfClass("Humanoid")
    if hum then
        -- Keep the rig together. Without these the humanoid can "die" in the
        -- viewport, break its joints, and leave the head floating while the
        -- body drops away.
        pcall(function() hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end)
        pcall(function() hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff end)
        pcall(function() hum.RequiresNeck = false end)
        pcall(function() hum.BreakJointsOnDeath = false end)
        pcall(function() hum.Health = hum.MaxHealth end)
        -- stop the state machine so it can't fall back to its own idle
        pcall(function() hum.EvaluateStateMachine = false end)
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
        side.animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
    end

    -- Anchor ONLY the root. Anchoring every part would freeze the limbs and
    -- kill animation playback; leaving the root loose lets the rig drift.
    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("BasePart") then
            d.CanCollide = false
            d.Massless = true
            d.Anchored = false
        elseif d:IsA("BodyMover") or d:IsA("BodyGyro") or d:IsA("BodyPosition")
            or d:IsA("AlignPosition") or d:IsA("AlignOrientation") or d:IsA("VectorForce") then
            d:Destroy()
        end
    end
    local root = clone:FindFirstChild("HumanoidRootPart") or clone.PrimaryPart
    if root then
        root.Anchored = true
        clone.PrimaryPart = root
    end

    -- yaw from this pane's own rotation bar
    local yaw = math.rad(Split[side.rotKey] or 0)
    pcall(function() clone:PivotTo(CFrame.new(0, 3, 0) * CFrame.Angles(0, yaw, 0)) end)
    side.clone = clone
    side.lastAnimId = nil

    -- a floor so the character reads as standing on something
    if not side.floor or not side.floor.Parent then
        local floor = F.own(Instance.new("Part"))
        floor.Name = "SplitFloor"
        floor.Size = Vector3.new(14, 1, 14)
        floor.Anchored = true; floor.CanCollide = false
        floor.Color = Color3.fromRGB(22, 20, 30)
        floor.Material = Enum.Material.SmoothPlastic
        floor.Parent = side.wm
        side.floor = floor
    end
    -- align the floor to the clone's actual feet
    local okB, cf, size = pcall(function()
        local a, b = clone:GetBoundingBox()
        return a, b
    end)
    local feetY = 3 - 3
    if okB and cf and size then feetY = cf.Y - size.Y / 2 end
    side.floor.CFrame = CFrame.new(0, feetY - 0.5, 0)
end

-- Re-yaw the clones without rebuilding them (driven by the rotation bars).
function Split.reface()
    for _, side in ipairs({ Split.L, Split.R }) do
        if side and side.clone then
            local yaw = math.rad(Split[side.rotKey] or 0)
            pcall(function() side.clone:PivotTo(CFrame.new(0, 3, 0) * CFrame.Angles(0, yaw, 0)) end)
        end
    end
end

function Split.refreshClones()
    if not Split.L then return end
    Split.loadClone(Split.L, character)
    Split.loadClone(Split.R, currentTarget and currentTarget.Character or nil)
    if Split.R then
        Split.R.label.Text = currentTarget and currentTarget.Name or "NO OPPONENT"
    end
end

-- Mirror a live animation onto the matching clone.
function Split.play(who, animId)
    if not Split.enabled or not animId or animId == "" then return end
    local side = (who == "OPPONENT") and Split.R or Split.L
    if not side or not side.animator then return end
    if side.lastAnimId == animId and side.track and side.track.IsPlaying then return end

    local ok, track = pcall(function()
        local a = Instance.new("Animation")
        a.AnimationId = "rbxassetid://" .. animId
        local t = side.animator:LoadAnimation(a)
        t.Priority = Enum.AnimationPriority.Action
        t.Looped = Split.loopMirrored   -- otherwise it ends and the rig goes limp
        return t
    end)
    if ok and track then
        for _, t in ipairs(side.animator:GetPlayingAnimationTracks()) do t:Stop(0) end
        track:Play(0.05)
        side.track = track
        side.lastAnimId = animId
    end
end

-- Re-fires the last animation if a track ended, so a pane never sits limp.
function Split.holdAnimations()
    for _, side in ipairs({ Split.L, Split.R }) do
        if side and side.animator and side.lastAnimId and Split.loopMirrored then
            if not side.track or not side.track.IsPlaying then
                local id = side.lastAnimId
                side.lastAnimId = nil
                Split.play(side == Split.R and "OPPONENT" or "PLAYER", id)
            end
        end
    end
end

-- One pose claims screen space from the other side.
function Split.claim(who)
    if not Split.enabled then return end
    local side, other
    if who == "PLAYER" then
        Split.targetBalance = Split.targetBalance + Split.claimGain
        side, other = Split.L, Split.R
    else
        Split.targetBalance = Split.targetBalance - Split.claimGain
        side, other = Split.R, Split.L
    end
    Split.targetBalance = math.clamp(Split.targetBalance, 0.18, 0.82)
    -- the claiming character lifts, the other settles
    if side then side.riseVel = side.riseVel + 7 end
    if other then other.riseVel = other.riseVel - 2.5 end
end

function Split.start()
    if Split.conn then return end
    Split.conn = F.own(RunService.RenderStepped:Connect(function(dt)
        if not Split.enabled then return end
        dt = math.clamp(dt, 0, 1/20)
        Split.holdAnimations()

        -- territory eases back toward even, then the divider lerps to it
        Split.targetBalance = 0.5 + (Split.targetBalance - 0.5) * math.exp(-Split.recentre * dt)
        local a = 1 - math.exp(-Split.slideSpeed * dt)
        Split.balance = Split.balance + (Split.targetBalance - Split.balance) * a
        Split.intro = Split.intro + (1 - Split.intro) * (1 - math.exp(-4 * dt))

        local b = math.clamp(Split.balance, 0.05, 0.95)
        if Split.L then
            Split.L.vp.Size = UDim2.new(b, -2, 1, 0)
            Split.L.vp.Position = UDim2.new(0, 0, 0, 0)
        end
        if Split.R then
            Split.R.vp.Size = UDim2.new(1 - b, -2, 1, 0)
            Split.R.vp.Position = UDim2.new(b, 2, 0, 0)
        end
        if Split.div then
            Split.div.Position = UDim2.new(b, -2, 0, 0)
            Split.div.BackgroundTransparency = 1 - Split.intro
        end

        -- cameras stay locked; only the characters breathe
        for _, side in ipairs({ Split.L, Split.R }) do
            if side and side.cam then
                side.cam.CFrame = CFrame.new(
                    Vector3.new(0, Split.height + 3, Split.dist),
                    Vector3.new(0, 3, 0))
                side.cam.FieldOfView = 55

                -- sprung rise so gaining ground reads as stepping up
                side.riseVel = side.riseVel + (-70 * side.rise - 11 * side.riseVel) * dt
                side.rise = side.rise + side.riseVel * dt
                if side.clone then
                    local yaw = math.rad(Split[side.rotKey] or 0)
                    local y = 3 + side.rise * Split.riseAmount
                    pcall(function()
                        side.clone:PivotTo(CFrame.new(0, y, 0) * CFrame.Angles(0, yaw, 0))
                    end)
                end
            end
        end
    end))
end

function Split.setEnabled(state)
    Split.enabled = state
    if state then
        if not Split.gui or not Split.gui.Parent then Split.build() else Split.refreshClones() end
        Split.gui.Enabled = true
        Split.start()
    elseif Split.gui then
        Split.gui.Enabled = false
    end
    if Split.refreshUI then Split.refreshUI() end
    F.notify(state and "Split screen ON — clones only, no map" or "Split screen OFF",
        state and "success" or "info")
end

-- ============================================================
--  HEALTH BAR — FNF-style, with icons that ride the boundary.
--  Your notes push you forward into their side; their poses
--  push you back. Where your icon sits tells you how close
--  you are to losing the exchange.
-- ============================================================
function Health.build()
    local old = PlayerGui:FindFirstChild("FNFHealthBar")
    if old then old:Destroy() end

    local sg = F.own(Instance.new("ScreenGui"))
    sg.Name = "FNFHealthBar"; sg.IgnoreGuiInset = true
    sg.ResetOnSpawn = false; sg.DisplayOrder = F.silZ(140)
    sg.Enabled = Health.enabled; sg.Parent = PlayerGui
    Health.gui = sg

    -- red vignette: four edges that crush inward as health runs out
    Health.vig = {}
    local edges = {
        { UDim2.new(1,0,0.32,0), UDim2.new(0,0,0,0), 90  },
        { UDim2.new(1,0,0.32,0), UDim2.new(0,0,0.68,0), 270 },
        { UDim2.new(0.26,0,1,0), UDim2.new(0,0,0,0), 0   },
        { UDim2.new(0.26,0,1,0), UDim2.new(0.74,0,0,0), 180 },
    }
    for i, e in ipairs(edges) do
        local f = Instance.new("Frame")
        f.Size, f.Position = e[1], e[2]
        f.BackgroundColor3 = Color3.fromRGB(190, 0, 18)
        f.BackgroundTransparency = 1
        f.BorderSizePixel = 0
        f.ZIndex = F.silZ(130)
        f.Parent = sg
        local g = Instance.new("UIGradient")
        g.Rotation = e[3]
        g.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        })
        g.Parent = f
        Health.vig[i] = f
    end
    -- faint red wash over the whole screen at the very bottom
    local wash = Instance.new("Frame")
    wash.Size = UDim2.new(1, 0, 1, 0)
    wash.BackgroundColor3 = Color3.fromRGB(120, 0, 10)
    wash.BackgroundTransparency = 1
    wash.BorderSizePixel = 0
    wash.ZIndex = F.silZ(129)
    wash.Parent = sg
    Health.vig.wash = wash

    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(0.55, 0, 0, 22)
    holder.Position = UDim2.new(0.5, 0, 1, -132)
    holder.AnchorPoint = Vector2.new(0.5, 0)
    holder.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
    holder.BorderSizePixel = 0
    holder.ZIndex = F.silZ(140); holder.Parent = sg
    F.uiCorner(holder, UDim.new(0, 6))
    F.uiStroke(holder, Color3.fromRGB(0, 0, 0), 3).Transparency = 0

    -- opponent owns the left portion
    local fillO = Instance.new("Frame")
    fillO.Size = UDim2.new(0.5, 0, 1, 0); fillO.Position = UDim2.new(0, 0, 0, 0)
    fillO.BackgroundColor3 = Color3.fromRGB(255, 60, 70)
    fillO.BorderSizePixel = 0; fillO.ZIndex = F.silZ(141); fillO.Parent = holder
    F.uiCorner(fillO, UDim.new(0, 5))
    Health.fillO = fillO

    -- you own the right portion
    local fillP = Instance.new("Frame")
    fillP.Size = UDim2.new(0.5, 0, 1, 0); fillP.Position = UDim2.new(0.5, 0, 0, 0)
    fillP.BackgroundColor3 = Color3.fromRGB(60, 230, 120)
    fillP.BorderSizePixel = 0; fillP.ZIndex = F.silZ(141); fillP.Parent = holder
    F.uiCorner(fillP, UDim.new(0, 5))
    Health.fillP = fillP

    local function makeIcon(color, anchorX)
        local ic = Instance.new("ImageLabel")
        ic.Size = UDim2.new(0, 46, 0, 46)
        ic.AnchorPoint = Vector2.new(anchorX, 0.5)
        ic.Position = UDim2.new(0.5, 0, 0.5, 0)
        ic.BackgroundColor3 = color
        ic.BackgroundTransparency = 0
        ic.Image = ""
        ic.BorderSizePixel = 0
        ic.ZIndex = F.silZ(143); ic.Parent = holder
        F.uiCorner(ic, UDim.new(0, 8))
        F.uiStroke(ic, Color3.fromRGB(0, 0, 0), 2).Transparency = 0
        return ic
    end
    Health.iconO = makeIcon(Color3.fromRGB(200, 50, 60), 1)
    Health.iconP = makeIcon(Color3.fromRGB(50, 190, 100), 0)

    local warn = Instance.new("TextLabel")
    warn.Size = UDim2.new(1, 0, 0, 18); warn.Position = UDim2.new(0, 0, 0, -22)
    warn.BackgroundTransparency = 1; warn.Text = ""
    warn.TextColor3 = Color3.fromRGB(255, 70, 70)
    warn.Font = Enum.Font.GothamBlack; warn.TextSize = 15
    warn.ZIndex = F.silZ(144); warn.Parent = holder
    Health.warn = warn
end

-- An icon box holds a decal ID or, with the FNF sprites imported, a
-- character name (bf, dad, gf, pico ...). Anything else comes back as "".
function Health.cleanIcon(text)
    text = string.lower((string.gsub(text or "", "%s", "")))
    if string.match(text, "^%a[%w%-]*$") then return text end   -- a name
    return (string.gsub(text, "%D", ""))                        -- an ID, however it was pasted
end

-- Returns the image for one side, and whether it's an FNF sprite. A name
-- uses the game's two-face icon: the second face shows while that side is
-- losing, and yours is mirrored so the two look at each other.
function Health.iconImage(value, side, losing)
    if value == "" then return nil, false end
    if string.match(value, "^%d+$") then return "rbxassetid://" .. value, false end
    local img = Skin.icon(value, side, losing)
    return img, img ~= nil
end

function Health.paintIcons()
    local d = Health.display or 0.5
    Health.loseP, Health.loseO = d < 0.2, d > 0.8
    -- a custom icon wins; otherwise the avatar portrait, on its team colour
    for _, s in ipairs({
        { ic = Health.iconP, value = Health.playerIcon, side = "P", losing = Health.loseP, portrait = Health.portraitP },
        { ic = Health.iconO, value = Health.oppIcon,    side = "O", losing = Health.loseO, portrait = Health.portraitO },
    }) do
        if s.ic then
            local img, isSprite = Health.iconImage(s.value, s.side, s.losing)
            s.ic.Image = img or (Health.portraits and s.portrait or "")
            s.ic.BackgroundTransparency = img and 1 or 0
            -- a cut-out sprite has no tile behind it, so no tile outline either
            local edge = s.ic:FindFirstChildOfClass("UIStroke")
            if edge then edge.Enabled = not isSprite end
        end
    end
end

function Health.setIcons(playerId, oppId)
    Health.playerIcon, Health.oppIcon = playerId or "", oppId or ""
    Health.paintIcons()
end

function Health.onHit(who)
    if not Health.enabled then return end
    if who == "PLAYER" then
        Health.hp = math.min(1, Health.hp + Health.gainPerNote)
    else
        Health.hp = math.max(0, Health.hp - Health.drainPerPose)
    end
end

-- Holding a note: a tap's gain lands on the press (onHit); after
-- that, every second the key stays down adds more, and the rate grows
-- exponentially the longer you hold, up to holdMax a second. Anything
-- shorter than a tap (Notes.startDelay) adds nothing extra.
function Health.holdBegin(dir) Health.holds[dir] = os.clock() end
function Health.holdEnd(dir) Health.holds[dir] = nil end

function Health.holdStep(dt)
    if Health.holdRate <= 0 then return end
    local now = os.clock()
    for _, t0 in pairs(Health.holds) do
        local held = now - t0 - Notes.startDelay
        if held > 0 then
            local rate = math.min(Health.holdRate * math.exp(Health.holdCurve * held), Health.holdMax)
            Health.hp = math.min(1, Health.hp + rate * dt)
        end
    end
end

function Health.reset()
    Health.hp, Health.display = 0.5, 0.5
    Health.holds = {}
end

function Health.start()
    if Health.conn then return end
    Health.conn = F.own(RunService.RenderStepped:Connect(function(dt)
        if not Health.enabled or not Health.gui then return end
        dt = math.clamp(dt, 0, 1/20)

        -- passive bleed only while an opponent is actually set
        if currentTarget then
            Health.hp = math.clamp(Health.hp - Health.passiveDrain * dt, 0, 1)
        end
        Health.holdStep(dt)

        Health.display = Health.display + (Health.hp - Health.display) * (1 - math.exp(-Health.smooth * dt))
        Health.syncStep()
        Health.drawVignette()
        local d = math.clamp(Health.display, 0.02, 0.98)

        -- boundary sits at (1 - hp): more health pushes it left, into their side
        local boundary = 1 - d
        if Health.fillO then Health.fillO.Size = UDim2.new(boundary, 0, 1, 0) end
        if Health.fillP then
            Health.fillP.Position = UDim2.new(boundary, 0, 0, 0)
            Health.fillP.Size = UDim2.new(d, 0, 1, 0)
        end
        -- your icon rides forward, theirs gets pushed back
        if Health.portraitSpot == "BESIDE" then
            -- fixed at the two ends, facing each other across the bar
            if Health.iconO then Health.iconO.Position = UDim2.new(0, -8, 0.5, 0) end
            if Health.iconP then Health.iconP.Position = UDim2.new(1,  8, 0.5, 0) end
        else
            if Health.iconO then Health.iconO.Position = UDim2.new(boundary, -4, 0.5, 0) end
            if Health.iconP then Health.iconP.Position = UDim2.new(boundary,  4, 0.5, 0) end
        end

        -- FNF icons swap to their losing face as the bar swings
        if (d < 0.2) ~= Health.loseP or (d > 0.8) ~= Health.loseO then Health.paintIcons() end

        if Health.warn then
            if d < 0.22 then
                Health.warn.Text = "LOSING GROUND"
                Health.warn.TextTransparency = 0.15 + math.abs(math.sin(os.clock() * 9)) * 0.55
            else
                Health.warn.Text = ""
            end
        end
    end))
end

-- Red edges that grow and throb as health runs out. Nothing above the
-- threshold; full strength, pulsing fastest, when the bar is empty.
function Health.drawVignette()
    local v = Health.vig
    if not v or not v[1] then return end
    local level = 0
    if Health.lowVignette and Health.vignetteAt > 0 then
        level = math.clamp((Health.vignetteAt - Health.display) / Health.vignetteAt, 0, 1)
    end
    -- heartbeat pulse that speeds up the closer you are to empty
    local rate = 4 + level * 6
    local pulse = 0.72 + 0.28 * math.abs(math.sin(os.clock() * rate))
    local strength = level * pulse
    for i = 1, 4 do
        v[i].BackgroundTransparency = 1 - strength * 0.92
    end
    if v.wash then
        v.wash.BackgroundTransparency = 1 - math.max(0, level - 0.6) * 0.45 * pulse
    end
end

-- Push the rap health onto your real Roblox health bar.
-- Client-side, so it shows on YOUR screen only; the server keeps your
-- real health and sends it again every time it changes there (a hit,
-- the game's regen ticking). That number lands on top of ours, so
-- whenever the Humanoid holds something we didn't write, it's your
-- real health: we keep it, and only a DROP in it counts as damage.
-- The gap between your real health and the bar is not damage, so
-- notes and holds can heal the bar back past it.
-- Rap drain never kills: 1 HP is the floor.
function Health.syncStep()
    if not Health.syncRoblox then return end
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    if Health.realFor ~= hum then
        Health.realFor, Health.real, Health.lastWritten = hum, nil, nil
    end

    local now = hum.Health
    if not Health.lastWritten or math.abs(now - Health.lastWritten) > 0.01 then
        -- the game took health off (a fall, a weapon, the game itself):
        -- the rap health loses the same, so the two agree
        if Health.respectDamage and Health.real and now < Health.real - 0.5 then
            local lost = (Health.real - now) / math.max(hum.MaxHealth, 1)
            Health.hp = math.clamp(Health.hp - lost, 0, 1)
            Health.display = math.clamp(Health.display - lost, 0, 1)
        end
        Health.real = now
    end

    local target = math.max(1, Health.display * hum.MaxHealth)
    hum.Health = target
    Health.lastWritten = target
end

-- Hand your real health back: the last number the game sent.
function Health.releaseRoblox()
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health > 0 then
        hum.Health = (Health.realFor == hum and Health.real) or hum.MaxHealth
    end
    Health.lastWritten = nil
end

function Health.setEnabled(state)
    Health.enabled = state
    if state then
        if not Health.gui or not Health.gui.Parent then Health.build() end
        Health.gui.Enabled = true
        Health.start()
    elseif Health.gui then
        Health.gui.Enabled = false
    end
    -- bar off means the battle's off: give the real health back
    if not state and Health.syncRoblox then Health.releaseRoblox() end
    if Health.refreshUI then Health.refreshUI() end
end

-- ============================================================
--  PERFECT DOUBLE NOTE — afterimage streak
--  Two different notes inside the perfect window spawn a ghost
--  copy of you that flies off in the direction of the note.
--  Note: input events are frame-bound, so the tightest window
--  that can actually fire is roughly one frame (~16ms at 60fps).
-- ============================================================
function Ghost.spawn(dir)
    pcall(Ghost.dash, dir)   -- the replicated half, if it's on
    local char = character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local wasArch = char.Archivable
    if not wasArch then char.Archivable = true end
    local ok, clone = pcall(function() return char:Clone() end)
    if not wasArch then char.Archivable = wasArch end
    if not ok or not clone then return end

    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end
    end
    local hum = clone:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        hum.EvaluateStateMachine = false
    end

    local parts = {}
    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored = true
            d.CanCollide = false     -- nothing bumps into it
            d.CanTouch = false       -- no Touched events fire off it
            d.CanQuery = false       -- invisible to raycasts and region checks
            d.Massless = true
            d.Transparency = math.max(d.Transparency, 0.45)
            table.insert(parts, d)
        elseif d:IsA("Decal") or d:IsA("Texture") then
            d.Transparency = 0.45
        elseif d:IsA("TouchTransmitter") or d:IsA("ClickDetector")
            or d:IsA("ProximityPrompt") or d:IsA("Fire") or d:IsA("Smoke") then
            d:Destroy()
        end
    end
    -- strip the humanoid so it can't walk, collide or be targeted
    local ghostHum = clone:FindFirstChildOfClass("Humanoid")
    if ghostHum then
        pcall(function() ghostHum.EvaluateStateMachine = false end)
        pcall(function() ghostHum.PlatformStand = true end)
        pcall(function() ghostHum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end)
    end

    local hl = F.own(Instance.new("Highlight"))
    hl.FillColor = Ghost.tint; hl.OutlineColor = Ghost.tint
    hl.FillTransparency = 0.55; hl.OutlineTransparency = 0.2
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = clone

    clone.Name = "FNFAfterimage"
    clone.Parent = Workspace

    -- travel direction, relative to how the character is facing
    local cf = root.CFrame
    local offset
    -- horizontal notes read as depth: LEFT throws the ghost forward,
    -- RIGHT throws it backward. Vertical notes stay vertical.
    if dir == "LEFT" then offset = cf.LookVector
    elseif dir == "RIGHT" then offset = -cf.LookVector
    elseif dir == "UP" then offset = Vector3.new(0, 1, 0)
    elseif dir == "DOWN" then offset = Vector3.new(0, -1, 0)
    else offset = -cf.LookVector end
    offset = offset * Ghost.distance

    local startCF = cf
    local life = Ghost.life
    for _, p in ipairs(parts) do
        TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Transparency = 1 }):Play()
    end
    TweenService:Create(hl, TweenInfo.new(life, Enum.EasingStyle.Quad),
        { FillTransparency = 1, OutlineTransparency = 1 }):Play()

    task.spawn(function()
        local t0 = os.clock()
        while os.clock() - t0 < life do
            local a = (os.clock() - t0) / life
            local eased = 1 - (1 - a) * (1 - a)
            pcall(function() clone:PivotTo(startCF + offset * eased) end)
            RunService.Heartbeat:Wait()
        end
        pcall(function() clone:Destroy() end)
    end)
end

-- FE DASH. The afterimage clone only exists on your screen: FE never sends
-- other players anything your client creates. Your own character's position
-- does reach them, because your client runs its physics. So this moves the
-- real you along the ghost's path, holds there long enough for the server to
-- pass it on, and brings you back. It moves you by deltas, so you can keep
-- walking through it and you end up exactly where you'd otherwise be.
function Ghost.dash(dir)
    if not Ghost.feDash or Ride.enabled then return end
    local char = character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not (root and hum) or hum.Health <= 0 or hum.Sit or root.Anchored then return end

    -- the same way the ghost goes; straight down would put you in the floor
    local look = root.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    local way
    if dir == "LEFT" and flat.Magnitude > 1e-3 then way = flat.Unit
    elseif dir == "RIGHT" and flat.Magnitude > 1e-3 then way = -flat.Unit
    elseif dir == "UP" then way = Vector3.new(0, 1, 0)
    else return end

    -- stop short of walls, so you never end up inside one
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { char }
    local dist = Ghost.dashDistance
    local hit = Workspace:Raycast(root.Position, way * (dist + 2), params)
    if hit then dist = math.max(0, (hit.Position - root.Position).Magnitude - 2) end
    if dist < 0.5 then return end
    local offset = way * dist

    Ghost.dashGen = Ghost.dashGen + 1
    local gen = Ghost.dashGen
    local snap = (Ghost.dashStyle == "TELEPORT")
    local outT, holdT, backT = 0.06, math.max(0.05, Ghost.dashHold), 0.1
    local t0 = os.clock()
    local applied = Vector3.new()
    task.spawn(function()
        while true do
            local t = os.clock() - t0
            local k
            if t < outT then k = snap and 1 or (t / outT)
            elseif t < outT + holdT then k = 1
            elseif t < outT + holdT + backT then k = snap and 0 or (1 - (t - outT - holdT) / backT)
            else k = 0 end
            -- a newer dash, a respawn or an unload: hand back what we moved
            local over = (Ghost.dashGen ~= gen) or not root.Parent or not F.alive
            if over then k = 0 end
            local want = offset * k
            local delta = want - applied
            if delta.Magnitude > 1e-4 and root.Parent then
                root.CFrame = root.CFrame + delta
                applied = want
            end
            if way.Y > 0 and k > 0 and root.Parent then
                -- hold the height while up there instead of falling through the beat
                local v = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
            end
            if k == 0 and (over or t >= outT + holdT + backT) then break end
            RunService.Heartbeat:Wait()
        end
    end)
end

-- Called on every note press. Returns true if it was a perfect double.
function Ghost.tryPerfect(dir)
    if not Ghost.enabled then
        Ghost.lastPress, Ghost.lastDir = os.clock(), dir
        return false
    end
    local now = os.clock()
    local perfect = (now - Ghost.lastPress) <= Ghost.window
        and Ghost.lastDir ~= nil and Ghost.lastDir ~= dir
        and (now - Ghost.lastSpawn) > 0.15

    Ghost.lastPress, Ghost.lastDir = now, dir
    if not perfect then return false end

    Ghost.lastSpawn = now
    Ghost.spawn(dir)
    F.notify("PERFECT DOUBLE", "success")
    FNFCamera:DoubleNoteZoom(1.6)          -- perfect doubles hit hardest
    if Chaos.enabled then Chaos.bigImpact(1.5) end
    return true
end

-- ============================================================
--  BOSS BATTLE CUTSCENE
--  Scales the opponent up and you down, then frames it from the
--  floor. Note: Model:ScaleTo is applied on your client only, so
--  the opponent sees themselves at normal size — this is a local
--  visual effect, not a replicated one.
-- ============================================================
function Boss.scaleModel(model, scale)
    if not model then return nil end
    local ok = pcall(function() model:ScaleTo(scale) end)
    return ok and model or nil
end

function Boss.enter()
    if Boss.active then return end
    local opp = currentTarget and currentTarget.Character or nil
    if not opp then
        F.notify("Set an opponent first — boss view needs a target", "warn")
        return
    end
    Boss.active = true

    -- remember current scale so we can put everything back
    pcall(function() Boss.savedOpp = opp:GetScale() end)
    pcall(function() Boss.savedPlayer = character and character:GetScale() or 1 end)

    Boss.scaledOpp = Boss.scaleModel(opp, Boss.savedOpp * Boss.oppScale)
    Boss.scaledPlayer = Boss.scaleModel(character, Boss.savedPlayer * Boss.playerScale)

    if not Boss.scaledOpp then
        F.notify("This rig can't be scaled — framing only", "warn")
    end

    FNFCamera:SetEnabled(true)
    FNFCamera.currentCFrame = nil      -- cut straight into the shot
    F.notify("BOSS BATTLE", "success")
    if Chaos.enabled then Chaos.bigImpact(1.6) end
end

function Boss.exit()
    if not Boss.active then return end
    Boss.active = false
    if Boss.scaledOpp then pcall(function() Boss.scaledOpp:ScaleTo(Boss.savedOpp) end) end
    if Boss.scaledPlayer then pcall(function() Boss.scaledPlayer:ScaleTo(Boss.savedPlayer) end) end
    Boss.scaledOpp, Boss.scaledPlayer = nil, nil
    FNFCamera.currentCFrame = nil
    F.notify("Boss view ended", "info")
end

function Boss.toggle()
    if Boss.active then Boss.exit() else Boss.enter() end
    if Boss.refreshUI then Boss.refreshUI() end
end

-- Rescale live if the sliders move while the cutscene is running.
function Boss.restyle()
    if not Boss.active then return end
    if Boss.scaledOpp then pcall(function() Boss.scaledOpp:ScaleTo(Boss.savedOpp * Boss.oppScale) end) end
    if Boss.scaledPlayer then pcall(function() Boss.scaledPlayer:ScaleTo(Boss.savedPlayer * Boss.playerScale) end) end
end

-- ============================================================
--  KEYBIND CHEAT SHEET — translucent overlay you can read
--  while playing, without opening the panel.
-- ============================================================
function Keys.rows()
    local out = {}
    local function add(k, d)
        table.insert(out, { key = (k == nil or k == "" or k == "None") and "--none--" or k, desc = d })
    end

    add("--", "NOTES")
    for _, row in ipairs(CurrentBindings) do
        add(row.key, row.dir)
    end

    add("--", "SECTIONS")
    add(sectionPrevKey, "Previous section")
    add(sectionNextKey, "Next section")

    add("--", "MODES")
    add(soloKey, "Solo mode")
    add(silhouetteKey, "Silhouette mode")
    add(Split.key, "Split screen")
    add(Health.key, "Health bar")
    add(Boss.key, "Boss battle view")
    add(Ride.key, "Ride lock")
    add(Fly.key, "Fly")
    add(Keys.overlayKey, "This list")
    add(Keys.beatKey, "Beat zoom")
    add(Pose.dodgeKey, "Dodge animation")
    add(Notes.key, "Hold streaks")
    add(Vid.boKey, "Black screen fade")
    add(Result.winKey, "Win")
    add(Result.loseKey, "Lose")
    add(Cam2.introKey, "Intro shot")
    add(Cam2.outroKey, "Outro shot")
    add(Cutscene.key, "Cutscene mode")

    add("--", "INTRO TRANSITIONS")
    for _, e in ipairs(Keys.intro) do add(e.key, e.label) end

    add("--", "CINEMATIC PRESETS")
    for _, e in ipairs(Keys.preset) do add(e.key, e.name) end

    return out
end

function Keys.build()
    local old = PlayerGui:FindFirstChild("FNFKeybindList")
    if old then old:Destroy() end

    local sg = F.own(Instance.new("ScreenGui"))
    sg.Name = "FNFKeybindList"; sg.IgnoreGuiInset = true
    sg.ResetOnSpawn = false; sg.DisplayOrder = F.silZ(135)
    sg.Enabled = Keys.overlayOn; sg.Parent = PlayerGui
    Keys.gui = sg

    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(0, 208, 0, 40)
    panel.Position = UDim2.new(0, 14, 0.5, 0)
    panel.AnchorPoint = Vector2.new(0, 0.5)
    panel.BackgroundColor3 = Color3.fromRGB(10, 9, 15)
    panel.BackgroundTransparency = Keys.opacity
    panel.BorderSizePixel = 0
    panel.AutomaticSize = Enum.AutomaticSize.Y
    panel.ZIndex = F.silZ(135); panel.Parent = sg
    F.uiCorner(panel, UDim.new(0, 10))
    local edge = F.uiStroke(panel, Color3.fromRGB(255, 255, 255), 1)
    edge.Transparency = math.clamp(Keys.opacity + 0.25, 0, 1)
    Keys.panel = panel

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 8); pad.PaddingBottom = UDim.new(0, 8)
    pad.PaddingLeft = UDim.new(0, 10); pad.PaddingRight = UDim.new(0, 10)
    pad.Parent = panel

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 2)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = panel

    Keys.list = panel
    Keys.refresh()
end

function Keys.refresh()
    local panel = Keys.list
    if not panel then return end
    for _, c in ipairs(panel:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
    end

    local order = 0
    for _, r in ipairs(Keys.rows()) do
        order = order + 1
        if r.key == "--" then
            local h = Instance.new("TextLabel")
            h.Size = UDim2.new(1, 0, 0, 16)
            h.BackgroundTransparency = 1
            h.Text = r.desc
            h.TextColor3 = THEMES[currentThemeName].accent
            h.Font = Enum.Font.GothamBold; h.TextSize = 9
            h.TextXAlignment = Enum.TextXAlignment.Left
            h.LayoutOrder = order
            h.ZIndex = F.silZ(137); h.Parent = panel
            F.regText(h)
        else
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, 0, 0, 15)
            row.BackgroundTransparency = 1
            row.LayoutOrder = order
            row.ZIndex = F.silZ(136); row.Parent = panel

            local chip = Instance.new("TextLabel")
            chip.Size = UDim2.new(0, 62, 1, 0)
            chip.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            chip.BackgroundTransparency = math.clamp(Keys.opacity + 0.25, 0, 1)
            chip.Text = r.key
            chip.TextColor3 = Color3.fromRGB(245, 245, 255)
            chip.Font = Enum.Font.GothamBold; chip.TextSize = 9
            chip.BorderSizePixel = 0
            chip.ZIndex = F.silZ(137); chip.Parent = row
            F.uiCorner(chip, UDim.new(0, 4))

            local desc = Instance.new("TextLabel")
            desc.Size = UDim2.new(1, -68, 1, 0); desc.Position = UDim2.new(0, 68, 0, 0)
            desc.BackgroundTransparency = 1
            desc.Text = r.desc
            desc.TextColor3 = Color3.fromRGB(215, 215, 230)
            desc.Font = Enum.Font.Gotham; desc.TextSize = 9
            desc.TextXAlignment = Enum.TextXAlignment.Left
            desc.ZIndex = F.silZ(137); desc.Parent = row
        end
    end
end

function Keys.applyOpacity()
    if Keys.panel then
        Keys.panel.BackgroundTransparency = Keys.opacity
        for _, s in ipairs(Keys.panel:GetChildren()) do
            if s:IsA("UIStroke") then s.Transparency = math.clamp(Keys.opacity + 0.25, 0, 1) end
        end
    end
    Keys.refresh()
end

function Keys.setOverlay(state)
    Keys.overlayOn = state
    if state then
        if not Keys.gui or not Keys.gui.Parent then Keys.build() else Keys.refresh() end
        Keys.gui.Enabled = true
    elseif Keys.gui then
        Keys.gui.Enabled = false
    end
    if Keys.refreshUI then Keys.refreshUI() end
end

-- Handles the intro / preset / overlay / beat hotkeys.
function Keys.handle(kn)
    if not kn or kn == "None" then return false end
    if kn == Keys.overlayKey then
        Keys.setOverlay(not Keys.overlayOn)
        return true
    end
    if kn == Keys.beatKey then
        FNFCamera:SetBeatZoom(not FNFCamera.beatZoom)
        if Keys.onBeatZoom then Keys.onBeatZoom() end
        F.notify(FNFCamera.beatZoom
            and ("Beat zoom on — " .. math.floor(StatusState.bpm or 100) .. " BPM")
            or "Beat zoom off", FNFCamera.beatZoom and "success" or "info")
        return true
    end
    for _, e in ipairs(Keys.intro) do
        if e.key ~= "None" and kn == e.key then
            F.playIntroTransition(e.name)
            F.notify("Intro: " .. e.label, "info")
            return true
        end
    end
    for _, e in ipairs(Keys.preset) do
        if e.key ~= "None" and kn == e.key then
            FNFCamera:ApplyPreset(e.name)
            if Keys.onPreset then Keys.onPreset(e.name) end
            F.notify("Camera preset: " .. e.name, "success")
            return true
        end
    end
    return false
end

-- ============================================================
--  SAVE SYSTEM v2
--
--  What changed from v1, and why v1 never worked:
--   * v1's startup call was accidentally nested inside another function,
--     so it never ran. Boot is now an explicit step in the launch sequence.
--   * v1 required writefile, readfile AND isfile. Executors differ, so each
--     function is found separately and only write + read are mandatory.
--   * v1 applied everything in one block — one bad field aborted the rest,
--     and at launch that could crash startup. Every section is isolated now.
--   * v1 loaded after the GUI was built, so the panel showed stale values.
--     Config now loads BEFORE the GUI, so it's built from your settings.
--   * Three slots, plus clipboard export/import as a fallback for
--     executors with no file access at all.
-- ============================================================
local HttpService = game:GetService("HttpService")

-- Find an executor function by trying the direct global, then getgenv().
local function findFn(name, direct)
    if typeof(direct) == "function" then return direct end
    local f
    pcall(function() f = getgenv()[name] end)
    if typeof(f) == "function" then return f end
    return nil
end

function Save.resolveApi()
    Save.api = {
        write      = findFn("writefile",  writefile),
        read       = findFn("readfile",   readfile),
        isfile     = findFn("isfile",     isfile),
        makefolder = findFn("makefolder", makefolder),
        isfolder   = findFn("isfolder",   isfolder),
        delfile    = findFn("delfile",    delfile),
        clip       = findFn("setclipboard", setclipboard) or findFn("toclipboard", toclipboard),
    }
    Save.available = (Save.api.write ~= nil and Save.api.read ~= nil)

    -- prefer a folder when we can make one; fall back to a flat file name
    Save.useFolder = false
    if Save.available and Save.api.makefolder then
        local ok = pcall(function()
            local exists = Save.api.isfolder and Save.api.isfolder(Save.folder)
            if not exists then Save.api.makefolder(Save.folder) end
        end)
        Save.useFolder = ok
    end
    return Save.available
end

function Save.path(slot)
    slot = slot or Save.slot
    if Save.useFolder then return Save.folder .. "/slot" .. slot .. ".json" end
    return Save.folder .. "_slot" .. slot .. ".json"
end

function Save.exists(slot)
    if not Save.available then return false end
    local p = Save.path(slot)
    if Save.api.isfile then
        local ok, r = pcall(Save.api.isfile, p)
        if ok then return r == true end
    end
    -- no isfile: a read that succeeds means it's there
    local ok, r = pcall(Save.api.read, p)
    return ok and type(r) == "string" and #r > 0
end

-- ---- JSON-safe conversion ---------------------------------------------
-- JSONEncode chokes on NaN/inf, Roblox datatypes and mixed tables, so we
-- normalise everything first.
function Save.encodeValue(v, depth)
    depth = depth or 0
    if depth > 14 then return nil end
    local t = typeof(v)
    if t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return nil end
        return v
    elseif t == "string" or t == "boolean" then
        return v
    elseif t == "Vector3" then
        return { __t = "V3", x = v.X, y = v.Y, z = v.Z }
    elseif t == "Color3" then
        return { __t = "C3", r = v.R, g = v.G, b = v.B }
    elseif t == "table" then
        local out = {}
        for k, x in pairs(v) do
            local kt = type(k)
            if kt == "string" or kt == "number" then
                local e = Save.encodeValue(x, depth + 1)
                if e ~= nil then out[k] = e end
            end
        end
        return out
    end
    return nil   -- functions, Instances, anything else is skipped
end

function Save.decodeValue(v)
    if type(v) ~= "table" then return v end
    if v.__t == "V3" then return Vector3.new(v.x or 0, v.y or 0, v.z or 0) end
    if v.__t == "C3" then return Color3.new(v.r or 0, v.g or 0, v.b or 0) end
    local out = {}
    for k, x in pairs(v) do out[k] = Save.decodeValue(x) end
    return out
end

function Save.serialize()
    local ok, res = pcall(function()
        local data = Save.collect()
        data.version = INJECTOR_VERSION
        data.savedAt = os.time()
        return HttpService:JSONEncode(Save.encodeValue(data))
    end)
    if ok then return res end
    Save.lastError = "encode: " .. tostring(res)
    return nil
end

function Save.deserialize(json)
    if type(json) ~= "string" or #json == 0 then return nil end
    local ok, res = pcall(function() return HttpService:JSONDecode(json) end)
    if not ok or type(res) ~= "table" then
        Save.lastError = "decode: " .. tostring(res)
        return nil
    end
    return Save.decodeValue(res)
end

function Save.collect()
    local binds = {}
    for _, r in ipairs(CurrentBindings) do
        local alts = {}
        for _, a in ipairs(r.alts or {}) do
            table.insert(alts, { id = a.id or "", chance = a.chance or 0 })
        end
        table.insert(binds, {
            dir = r.dir, key = r.key, id = r.id,
            speedMult = r.speedMult, holdLoop = r.holdLoop, alts = alts,
            mode = r.mode or "CYCLE",
        })
    end

    local secs = {}
    for _, s in ipairs(sections) do
        table.insert(secs, { name = s.name, ids = {
            LEFT = s.ids.LEFT, DOWN = s.ids.DOWN, UP = s.ids.UP, RIGHT = s.ids.RIGHT } })
    end

    local favs = {}
    for _, f in ipairs(favorites) do table.insert(favs, { name = f.name, id = f.id }) end
    local list = {}
    for _, p in ipairs(playlist) do table.insert(list, { name = p.name, id = p.id, delay = p.delay }) end

    local introKeys, presetKeys = {}, {}
    for _, e in ipairs(Keys.intro) do table.insert(introKeys, { name = e.name, key = e.key }) end
    for _, e in ipairs(Keys.preset) do table.insert(presetKeys, { name = e.name, key = e.key }) end

    return {
        version = INJECTOR_VERSION,
        defaultsVersion = 3,
        tourSeen = Intro.seen,
        binds = binds,
        sections = secs,
        currentSection = currentSectionIdx,
        favorites = favs,
        playlist = list,
        faceIds = { LEFT = faceIds.LEFT, DOWN = faceIds.DOWN, UP = faceIds.UP, RIGHT = faceIds.RIGHT },
        theme = currentThemeName,
        idleBPM = idleBPM, baseBPM = BASE_BPM,
        legsLocked = legsLocked,
        vinyl = { id = VINYL_DECAL_ID, rpm = vinylBaseRPM },

        cutterResponse = { reach = Cut.reach, snap = Cut.snap, reverse = Cut.reverse,
                           returnPause = Cut.returnPause, returnTime = Cut.returnTime,
                           holdAfterReturn = Cut.holdAfterReturn },
        cutter = { id = cutterAnimId, slices = {
            LEFT = cutterSlices.LEFT, DOWN = cutterSlices.DOWN,
            UP = cutterSlices.UP, RIGHT = cutterSlices.RIGHT } },

        keys = {
            solo = soloKey, silhouette = silhouetteKey,
            sectionPrev = sectionPrevKey, sectionNext = sectionNextKey,
            split = Split.key, health = Health.key, boss = Boss.key,
            overlay = Keys.overlayKey, beat = Keys.beatKey, opacity = Keys.opacity,
            intro = introKeys, preset = presetKeys,
        },

        camera = {
            preset = FNFCamera.preset,
            distance = FNFCamera.camDistance, height = FNFCamera.camHeight,
            horizontal = FNFCamera.camHorizontal, angle = FNFCamera.camAngle,
            flipped = FNFCamera.camFlipped, fov = CAM_CFG.BaseFOV,
            bars = CAM_CFG.BarsEnabled,
            settleEnabled = FNFCamera.settleEnabled, settleAfter = FNFCamera.settleAfter,
            orbitSpeed = FNFCamera.orbitSpeed, orbitAmp = FNFCamera.orbitAmp,
            dutch = FNFCamera.dutch, handheld = FNFCamera.handheld, lead = FNFCamera.lead,
            beatZoom = FNFCamera.beatZoom, beatPower = FNFCamera.beatPower,
            snapHits = FNFCamera.snapHits, nudgeScale = FNFCamera.nudgeScale,
            tiltScale = FNFCamera.tiltScale, punchScale = FNFCamera.punchScale,
            returnSpeed = FNFCamera.returnSpeed,
            beatAccent = FNFCamera.beatAccent,
        },

        chaos = {
            master = Chaos.master, shake = Chaos.shake, zoomPunch = Chaos.zoomPunch,
            warp = Chaos.warp, glitch = Chaos.glitch, flash = Chaos.flash,
            readability = Chaos.readability, beatSync = Chaos.beatSync,
        },

        sil = {
            strength = SilFX.strength, fadeSpeed = SilFX.fadeSpeed,
            includePlayer = SilFX.includePlayer, includeOpponent = SilFX.includeOpponent,
            alwaysOnTop = SilFX.alwaysOnTop,
        },

        split = {
            dist = Split.dist, height = Split.height,
            rotL = Split.rotL, rotR = Split.rotR,
            claimGain = Split.claimGain, slideSpeed = Split.slideSpeed,
            loopMirrored = Split.loopMirrored,
        },

        health = {
            syncRoblox = Health.syncRoblox, respectDamage = Health.respectDamage,
            lowVignette = Health.lowVignette, vignetteAt = Health.vignetteAt,
            gainPerNote = Health.gainPerNote, drainPerPose = Health.drainPerPose,
            passiveDrain = Health.passiveDrain, smooth = Health.smooth,
            playerIcon = Health.playerIcon, oppIcon = Health.oppIcon,
            holdRate = Health.holdRate, holdCurve = Health.holdCurve, holdMax = Health.holdMax,
        },

        arrows = {
            x = Arrows.x, y = Arrows.y, offX = Arrows.offX, offY = Arrows.offY,
            size = Arrows.size, gap = Arrows.gap,
            draggable = Arrows.draggable, noteEnabled = Arrows.noteEnabled,
            noteDir = Arrows.noteDir, noteSpeed = Arrows.noteSpeed, noteLife = Arrows.noteLife,
            trail = Arrows.trail, beatBob = Arrows.beatBob,
            splash = Arrows.splash, combo = Arrows.combo, tilt = Arrows.tilt,
            sprites = Arrows.sprites,
            oppShow = Arrows.oppShow, oppX = Arrows.oppX, oppY = Arrows.oppY,
            oppOffX = Arrows.oppOffX, oppOffY = Arrows.oppOffY,
        },

        arms = { enabled = Arms.enabled, firstPerson = Arms.firstPerson, dirs = Arms.dirs,
                 mixOn = Arms.mixOn, mixFade = Arms.mixFade, mix = Arms.mix,
                 calm = Arms.calm, full = Arms.full, slowNps = Arms.slowNps, fastNps = Arms.fastNps,
                 window = Arms.window, blendIn = Arms.blendIn, fadeOut = Arms.fadeOut,
                 straighten = Arms.straighten },
        chars = { enabled = Chars.enabled, scale = Chars.scale, x = Chars.x, y = Chars.y,
                  offX = Chars.offX, offY = Chars.offY, draggable = Chars.draggable,
                  showOpp = Chars.showOpp, freeOpp = Chars.freeOpp, mode = Chars.mode,
                  follow = Chars.follow, worldScale = Chars.worldScale,
                  oppX = Chars.oppX, oppY = Chars.oppY, oppOffX = Chars.oppOffX, oppOffY = Chars.oppOffY },

        ride = { key = Ride.key, pingComp = Ride.pingComp, pingScale = Ride.pingScale,
                 pingSource = Ride.pingSource, extraMs = Ride.extraMs,
                 walkWith = Ride.walkWith, jumpWith = Ride.jumpWith,
                 clampEdges = Ride.clampEdges, edgeMargin = Ride.edgeMargin,
                 gravityScale = Ride.gravityScale, pickRadius = Ride.pickRadius,
                 shake = Ride.shake, wind = Ride.wind, speedFov = Ride.speedFov,
                 gLean = Ride.gLean, maxSpeedAt = Ride.maxSpeedAt, minSpeed = Ride.minSpeed,
                 shakeScale = Ride.shakeScale, windScale = Ride.windScale,
                 leanScale = Ride.leanScale,
                 guess = Ride.guess, seatFirst = Ride.seatFirst, walls = Ride.walls,
                 noCollide = Ride.noCollide, showView = Ride.showView, routeSecs = Ride.routeSecs },

        fly = { key = Fly.key, speed = Fly.speed, lookFly = Fly.lookFly, poseMove = Fly.poseMove,
                poseDist = Fly.poseDist, poseTime = Fly.poseTime, layout = Fly.layout,
                returnHome = Fly.returnHome, returnTime = Fly.returnTime, snapCut = Fly.snapCut, hover = Fly.hover,
                lean = Fly.lean, anims = Fly.anims },

        air = { rounds = Air.rounds, damage = Air.damage, dashDist = Air.dashDist, knock = Air.knock,
                koHold = Air.koHold, circle = Air.circle, circleSpeed = Air.circleSpeed,
                keepClose = Air.keepClose, maxDist = Air.maxDist, sameArrow = Air.sameArrow,
                clashWindow = Air.clashWindow, tpDist = Air.tpDist,
                jabLEFT = Air.jabLEFT, jabDOWN = Air.jabDOWN, jabUP = Air.jabUP, jabRIGHT = Air.jabRIGHT,
                hitAnim = Air.hitAnim, koAnim = Air.koAnim, winAnim = Air.winAnim },

        idle = { id = Idle.id, auto = Idle.auto },
        copy = { walkToo = Copy.walkToo, sync = Copy.sync, speed = Copy.speed, into = Copy.into },

        menu = { auto = Menu.auto, scale = Menu.scale },

        cam2 = { pulseEvery = Cam2.pulseEvery, beatShake = Cam2.beatShake,
                 oppZoom = Cam2.oppZoom, oppZoomPower = Cam2.oppZoomPower, oppAim = Cam2.oppAim,
                 dirShake = Cam2.dirShake, dirShakePower = Cam2.dirShakePower,
                 healthDist = Cam2.healthDist, healthClosest = Cam2.healthClosest,
                 introStyle = Cam2.introStyle, outroStyle = Cam2.outroStyle,
                 shotTime = Cam2.shotTime, outroHold = Cam2.outroHold,
                 outroOnResult = Cam2.outroOnResult, introOnOpponent = Cam2.introOnOpponent,
                 introKey = Cam2.introKey, outroKey = Cam2.outroKey, presets = Cam2.presets },
        cutscene = { key = Cutscene.key, hideRoblox = Cutscene.hideRoblox, bars = Cutscene.bars },
        silplus = { outline = SilFX.outline, outlineColor = SilFX.outlineColor,
                    splitColors = SilFX.splitColors, playerColor = SilFX.playerColor,
                    oppColor = SilFX.oppColor, spotlight = SilFX.spotlight, spotDim = SilFX.spotDim },
        portraits = { on = Health.portraits, spot = Health.portraitSpot },

        mobile = { layoutMode = Mobile.layoutMode, haptics = Mobile.haptics, landscape = Mobile.landscape,
                   hideDesktop = Mobile.hideDesktop,
                   mode = Mobile.mode, size = Mobile.size, spread = Mobile.spread,
                   pairGap = Mobile.pairGap, bottom = Mobile.bottom, idleFade = Mobile.idleFade,
                   hideStrip = Mobile.hideStrip },

        result = { winKey = Result.winKey, loseKey = Result.loseKey, cheerId = Result.cheerId,
                   cheerLoop = Result.cheerLoop, cheerTime = Result.cheerTime, sitId = Result.sitId,
                   flingSpeed = Result.flingSpeed, lift = Result.lift, spin = Result.spin,
                   direction = Result.direction, getUpAfter = Result.getUpAfter, banner = Result.banner },

        video = { volume = Vid.volume, opacity = Vid.opacity, looped = Vid.looped,
                  display = Vid.display, scale = Vid.scale, lastFile = Vid.lastFile,
                  boKey = Vid.boKey, boFadeIn = Vid.boFadeIn, boHold = Vid.boHold,
                  boFadeOut = Vid.boFadeOut },

        notes = { enabled = Notes.enabled, key = Notes.key, grow = Notes.grow,
                  fullTime = Notes.fullTime, startDelay = Notes.startDelay, length = Notes.length },

        pose = { reach = Pose.reach, snap = Pose.snap,
                 dodgeKey = Pose.dodgeKey, dodgeId = Pose.dodgeId, dodgeSpeed = Pose.dodgeSpeed },

        hold = { enabled = Hold.enabled, duration = Hold.duration, shortAt = Hold.shortAt,
                 holdAll = Hold.holdAll, cutter = Hold.cutter, fadeOut = Hold.fadeOut,
                 untilNext = Hold.untilNext },

        spacing = {
            enabled = SPACING.enabled, stepIn = SPACING.stepIn, bothBonus = SPACING.bothBonus,
            stepTime = SPACING.stepTime, returnDelay = SPACING.returnDelay,
            returnTime = SPACING.returnTime, minGap = SPACING.minGap,
            stepEase = SPACING.stepEase, returnEase = SPACING.returnEase,
        },

        ghost = { window = Ghost.window, life = Ghost.life, distance = Ghost.distance,
                  zoom = FNFCamera.dnPower, feDash = Ghost.feDash, dashStyle = Ghost.dashStyle,
                  dashDistance = Ghost.dashDistance, dashHold = Ghost.dashHold },

        boss = {
            oppScale = Boss.oppScale, playerScale = Boss.playerScale,
            dist = Boss.dist, height = Boss.height,
            lookHeight = Boss.lookHeight, bars = Boss.bars,
        },

        fight = {
            pushPerHit = fightState.pushPerHit, pushPerDouble = fightState.pushPerDouble,
            momentumCap = fightState.momentumCap,
            proximityDist = proximityBlockDist, proximityOn = proximityBlockEnabled,
            rpMode = rpModeEnabled,
        },
    }
end

local function pick(v, fallback) if v == nil then return fallback end return v end

-- Every section runs on its own, so one bad or outdated field can't stop
-- the rest of your settings loading. Returns (applied, failedSections).
function Save.apply(d, silentUi)
    if type(d) ~= "table" then return false, {} end
    local failed = {}
    local function sec(name, fn)
        local ok, err = pcall(fn)
        if not ok then
            table.insert(failed, name)
            F.log("save/" .. name .. " failed: " .. tostring(err))
        end
    end
    local function num(v, fallback) return type(v) == "number" and v or fallback end
    local function str(v, fallback) return (type(v) == "string" and v ~= "") and v or fallback end

    sec("binds", function()
        if type(d.binds) ~= "table" then return end
        for i, b in ipairs(d.binds) do
            local r = CurrentBindings[i]
            if r and type(b) == "table" then
                r.key = str(b.key, r.key)
                r.id = str(b.id, r.id)
                r.speedMult = num(b.speedMult, r.speedMult)
                r.holdLoop = pick(b.holdLoop, r.holdLoop)
                r.alts = {}
                for _, a in ipairs(b.alts or {}) do
                    if type(a) == "table" then
                        table.insert(r.alts, { id = tostring(a.id or ""), chance = num(a.chance, 0) })
                    end
                end
                if b.mode == "CYCLE" or b.mode == "RANDOM" or b.mode == "WEIGHTED" then
                    r.mode = b.mode
                end
                r.cycleIdx = 0
                if r.keyBtn then r.keyBtn.Text = r.key end
            end
        end
    end)

    sec("sections", function()
        if type(d.sections) ~= "table" or #d.sections == 0 then return end
        local new = {}
        for _, s in ipairs(d.sections) do
            if type(s) == "table" and type(s.ids) == "table" then
                table.insert(new, { name = str(s.name, "Section"), ids = {
                    LEFT = str(s.ids.LEFT, "0"), DOWN = str(s.ids.DOWN, "0"),
                    UP = str(s.ids.UP, "0"), RIGHT = str(s.ids.RIGHT, "0") } })
            end
        end
        if #new > 0 then
            sections = new
            currentSectionIdx = math.clamp(num(d.currentSection, 1), 1, #sections)
        end
    end)

    sec("favorites", function()
        if type(d.favorites) ~= "table" then return end
        favorites = {}
        for _, f in ipairs(d.favorites) do
            if type(f) == "table" and f.id then
                table.insert(favorites, { name = str(f.name, "Fav"), id = tostring(f.id) })
            end
        end
    end)

    sec("playlist", function()
        if type(d.playlist) ~= "table" then return end
        playlist = {}
        for _, p in ipairs(d.playlist) do
            if type(p) == "table" and p.id then
                table.insert(playlist, { name = str(p.name, "Track"), id = tostring(p.id), delay = num(p.delay, 1) })
            end
        end
    end)

    sec("faces", function()
        if type(d.faceIds) ~= "table" then return end
        for _, k in ipairs({ "LEFT", "DOWN", "UP", "RIGHT" }) do
            if type(d.faceIds[k]) == "string" then faceIds[k] = d.faceIds[k] end
        end
    end)

    sec("theme", function()
        if type(d.theme) == "string" and THEMES[d.theme] then
            currentThemeName = d.theme
            rgbCycleOn = (d.theme == "RGB")
        end
    end)

    sec("bpm", function()
        idleBPM = num(d.idleBPM, idleBPM)
        BASE_BPM = num(d.baseBPM, BASE_BPM)
        StatusState.bpm = idleBPM
    end)

    sec("vinyl", function()
        if type(d.vinyl) ~= "table" then return end
        VINYL_DECAL_ID = type(d.vinyl.id) == "string" and d.vinyl.id or VINYL_DECAL_ID
        vinylBaseRPM = num(d.vinyl.rpm, vinylBaseRPM)
    end)

    sec("cutter", function()
        if type(d.cutterResponse) == "table" then
            Cut.reach = num(d.cutterResponse.reach, Cut.reach)
            if type(d.cutterResponse.snap) == "boolean" then Cut.snap = d.cutterResponse.snap end
            local rv = d.cutterResponse.reverse
            if rv == "OFF" or rv == "AUTO" or rv == "RELEASE" then Cut.reverse = rv end
            Cut.returnPause = num(d.cutterResponse.returnPause, Cut.returnPause)
            Cut.returnTime = num(d.cutterResponse.returnTime, Cut.returnTime)
            if type(d.cutterResponse.holdAfterReturn) == "boolean" then
                Cut.holdAfterReturn = d.cutterResponse.holdAfterReturn
            end
        end
        if type(d.cutter) == "table" then
            -- an empty saved id keeps the default instead of wiping it
            cutterAnimId = str(d.cutter.id, cutterAnimId)
            for _, k in ipairs({ "LEFT", "DOWN", "UP", "RIGHT" }) do
                local s = d.cutter.slices and d.cutter.slices[k]
                if type(s) == "table" then
                    cutterSlices[k] = {
                        start = num(s.start, 0), stop = num(s.stop, 0),
                        id = type(s.id) == "string" and s.id or "",
                    }
                end
            end
        end
    end)

    sec("keys", function()
        local k = d.keys
        if type(k) ~= "table" then return end
        soloKey = str(k.solo, soloKey)
        silhouetteKey = str(k.silhouette, silhouetteKey)
        sectionPrevKey = str(k.sectionPrev, sectionPrevKey)
        sectionNextKey = str(k.sectionNext, sectionNextKey)
        Split.key = str(k.split, Split.key)
        Health.key = str(k.health, Health.key)
        Boss.key = str(k.boss, Boss.key)
        Keys.overlayKey = str(k.overlay, Keys.overlayKey)
        Keys.beatKey = str(k.beat, Keys.beatKey)
        Keys.opacity = num(k.opacity, Keys.opacity)
        for _, e in ipairs(k.intro or {}) do
            for _, t in ipairs(Keys.intro) do
                if type(e) == "table" and t.name == e.name then t.key = str(e.key, t.key) end
            end
        end
        for _, e in ipairs(k.preset or {}) do
            for _, t in ipairs(Keys.preset) do
                if type(e) == "table" and t.name == e.name then t.key = str(e.key, t.key) end
            end
        end
    end)

    -- plain config tables: copy only keys that already exist, and only when
    -- the type matches, so an old save can never inject junk into a module
    local function copyInto(tbl, data, skip)
        if type(data) ~= "table" then return end
        for key, val in pairs(data) do
            if not (skip and skip[key]) and tbl[key] ~= nil and type(tbl[key]) == type(val) then
                tbl[key] = val
            end
        end
    end

    sec("ride",    function() copyInto(Ride, d.ride, { enabled = true }) end)
    sec("fly",     function() copyInto(Fly, d.fly, { enabled = true }) end)
    sec("air",     function() copyInto(Air, d.air, { on = true }) end)
    sec("idle",    function()
        if type(d.idle) ~= "table" then return end
        Idle.id = type(d.idle.id) == "string" and d.idle.id:gsub("%D", "") or ""
        Idle.auto = (d.idle.auto == true) and Idle.id ~= ""
    end)
    sec("copy",    function()
        copyInto(Copy, d.copy, { on = true, target = true, seen = true, names = true, links = true,
                                 tracks = true, fillUsed = true })
        if Copy.into ~= "BINDS" and Copy.into ~= "CUTTER" then Copy.into = "BINDS" end
        Copy.speed = math.clamp(Copy.speed, 0.25, 2)
    end)
    sec("hold",    function() copyInto(Hold, d.hold) end)
    sec("pose",    function() copyInto(Pose, d.pose, { cache = true, owner = true }) end)
    sec("notes",   function() copyInto(Notes, d.notes, { held = true }) end)
    sec("video",   function() copyInto(Vid, d.video) end)
    sec("result",  function() copyInto(Result, d.result) end)
    sec("mobile",  function() copyInto(Mobile, d.mobile, { active = true }) end)
    sec("menu",    function() copyInto(Menu, d.menu, { main = true, scaleObj = true, current = true }) end)
    sec("cam2",    function()
        copyInto(Cam2, d.cam2, { presets = true, shot = true })
        if type(d.cam2) == "table" and type(d.cam2.presets) == "table" then
            local clean = {}
            for _, p in ipairs(d.cam2.presets) do
                if type(p) == "table" and type(p.name) == "string" and type(p.data) == "table" then
                    table.insert(clean, { name = p.name, data = p.data })
                end
            end
            Cam2.presets = clean
        end
    end)
    sec("cutscene", function() copyInto(Cutscene, d.cutscene, { active = true }) end)
    sec("silplus",  function() copyInto(SilFX, d.silplus) end)
    sec("portraits", function()
        if type(d.portraits) == "table" then
            if type(d.portraits.on) == "boolean" then Health.portraits = d.portraits.on end
            if d.portraits.spot == "BESIDE" or d.portraits.spot == "ON" then Health.portraitSpot = d.portraits.spot end
        end
    end)
    sec("spacing", function() copyInto(SPACING, d.spacing) end)
    sec("chaos",   function() copyInto(Chaos, d.chaos, { enabled = true }) end)
    sec("sil",     function() copyInto(SilFX, d.sil) end)
    sec("split",   function() copyInto(Split, d.split, { enabled = true }) end)
    sec("health",  function() copyInto(Health, d.health, { enabled = true, hp = true, display = true, holds = true }) end)
    sec("ghost",   function()
        copyInto(Ghost, d.ghost)
        if type(d.ghost) == "table" then FNFCamera.dnPower = num(d.ghost.zoom, FNFCamera.dnPower) end
    end)
    sec("boss",    function() copyInto(Boss, d.boss, { active = true }) end)
    sec("arms",    function()
        local a = d.arms
        if type(a) ~= "table" then return end
        copyInto(Arms, a, { dirs = true, mix = true })
        -- mix slots: three per note, each field only if it's the right type
        for _, dir in ipairs(ARROW_ORDER) do
            local src = type(a.mix) == "table" and a.mix[dir]
            if type(src) == "table" then
                for i = 1, 3 do
                    local from, to = src[i], Arms.mix[dir][i]
                    if type(from) == "table" then
                        if type(from.id) == "string" then to.id = from.id end
                        if type(from.share) == "number" then to.share = from.share end
                        if type(from.at) == "number" then to.at = from.at end
                        if type(from.over) == "boolean" then to.over = from.over end
                        if type(from.speed) == "boolean" then to.speed = from.speed end
                    end
                end
            end
        end
        -- per note: only the four directions, only the right types
        for _, dir in ipairs(ARROW_ORDER) do
            local src, dst = type(a.dirs) == "table" and a.dirs[dir], Arms.dirs[dir]
            if type(src) == "table" then
                if src.arm == "AUTO" or src.arm == "LEFT" or src.arm == "RIGHT" or src.arm == "BOTH" then dst.arm = src.arm end
                for _, k in ipairs({ "h", "v", "max" }) do
                    if type(src[k]) == "number" then dst[k] = src[k] end
                end
            end
        end
    end)
    sec("chars",   function() copyInto(Chars, d.chars) end)
    sec("arrows",  function()
        copyInto(Arrows, d.arrows)
        Arrows.hitSize = Arrows.size * 1.16
    end)

    sec("camera", function()
        local c = d.camera
        if type(c) ~= "table" then return end
        if type(c.preset) == "string" and CAM_PRESETS[c.preset] then FNFCamera:ApplyPreset(c.preset) end
        FNFCamera.camDistance   = num(c.distance, FNFCamera.camDistance)
        FNFCamera.camHeight     = num(c.height, FNFCamera.camHeight)
        FNFCamera.camHorizontal = num(c.horizontal, FNFCamera.camHorizontal)
        FNFCamera.camAngle      = num(c.angle, FNFCamera.camAngle)
        FNFCamera.camFlipped    = pick(c.flipped, FNFCamera.camFlipped)
        CAM_CFG.BaseFOV         = num(c.fov, CAM_CFG.BaseFOV)
        CAM_CFG.BarsEnabled     = pick(c.bars, CAM_CFG.BarsEnabled)
        FNFCamera.settleEnabled = pick(c.settleEnabled, FNFCamera.settleEnabled)
        FNFCamera.settleAfter   = num(c.settleAfter, FNFCamera.settleAfter)
        FNFCamera.orbitSpeed    = num(c.orbitSpeed, FNFCamera.orbitSpeed)
        FNFCamera.orbitAmp      = num(c.orbitAmp, FNFCamera.orbitAmp)
        FNFCamera.dutch         = num(c.dutch, FNFCamera.dutch)
        FNFCamera.handheld      = num(c.handheld, FNFCamera.handheld)
        FNFCamera.lead          = num(c.lead, FNFCamera.lead)
        FNFCamera.beatPower     = num(c.beatPower, FNFCamera.beatPower)
        FNFCamera.snapHits      = pick(c.snapHits, FNFCamera.snapHits)
        FNFCamera.nudgeScale    = num(c.nudgeScale, FNFCamera.nudgeScale)
        FNFCamera.tiltScale     = num(c.tiltScale, FNFCamera.tiltScale)
        FNFCamera.punchScale    = num(c.punchScale, FNFCamera.punchScale)
        FNFCamera.returnSpeed   = num(c.returnSpeed, FNFCamera.returnSpeed)
        FNFCamera.beatAccent    = num(c.beatAccent, FNFCamera.beatAccent)
        if c.beatZoom == true then FNFCamera:SetBeatZoom(true) end
    end)

    sec("fight", function()
        local f = d.fight
        if type(f) ~= "table" then return end
        fightState.pushPerHit    = num(f.pushPerHit, fightState.pushPerHit)
        fightState.pushPerDouble = num(f.pushPerDouble, fightState.pushPerDouble)
        fightState.momentumCap   = num(f.momentumCap, fightState.momentumCap)
        proximityBlockDist       = num(f.proximityDist, proximityBlockDist)
        proximityBlockEnabled    = pick(f.proximityOn, proximityBlockEnabled)
        if type(f.rpMode) == "boolean" then rpModeEnabled = f.rpMode end
    end)

    -- anyone with a save file from before the tour existed isn't new
    if d.tourSeen == true or d.tourSeen == nil then Intro.seen = true end

    -- ride lead: AVERAGE turned out to be the wrong number; saves from before
    -- defaults v3 move to MINE (plus the new screen-delay allowance) once
    if (tonumber(d.defaultsVersion) or 1) < 3 then
        Ride.pingSource = "MINE"
        if (Ride.extraMs or 0) < 50 then Ride.extraMs = 50 end
    end

    -- saves from before defaults v2 had these switched on without you asking
    if (tonumber(d.defaultsVersion) or 1) < 2 then
        FNFCamera.snapHits = false
        FNFCamera.settleEnabled = false
        SPACING.enabled = false
        rpModeEnabled = false
    end

    return true, failed
end

-- ---- file operations ----------------------------------------------------
function Save.write(slot, quiet)
    slot = slot or Save.slot
    if not Save.available then
        if not quiet then F.notify("No file access here — use EXPORT instead", "error") end
        return false
    end
    local json = Save.serialize()
    if not json then
        if not quiet then F.notify("Couldn't encode settings: " .. tostring(Save.lastError), "error") end
        return false
    end
    local ok, err = pcall(Save.api.write, Save.path(slot), json)
    if not ok then
        Save.lastError = "write: " .. tostring(err)
        if not quiet then F.notify("Save failed: " .. tostring(err), "error") end
        return false
    end
    Save.lastJson = json
    Save.lastSaved = os.date("%H:%M:%S")
    Save.lastError = nil
    if Save.refreshUI then Save.refreshUI() end
    if not quiet then F.notify("Saved to slot " .. slot, "success") end
    return true
end

function Save.read(slot)
    slot = slot or Save.slot
    if not Save.available then return nil, "no file access" end
    local ok, json = pcall(Save.api.read, Save.path(slot))
    if not ok or type(json) ~= "string" or #json == 0 then return nil, "no save in slot " .. slot end
    local data = Save.deserialize(json)
    if not data then return nil, "save file is corrupt" end
    return data, json
end

-- Runtime load: apply, then rebuild the panel so every field shows it.
function Save.load(slot)
    slot = slot or Save.slot
    local data, info = Save.read(slot)
    if not data then F.notify("Load failed — " .. tostring(info), "error"); return false end
    local _, failed = Save.apply(data)
    Save.lastJson = info
    Save.lastLoaded = os.date("%H:%M:%S")
    Save.slot = slot
    Save.rebuildAfterLoad()
    if #failed > 0 then
        F.notify("Loaded slot " .. slot .. " — skipped: " .. table.concat(failed, ", "), "warn")
    else
        F.notify("Loaded slot " .. slot, "success")
    end
    return true
end

-- Rebuild everything that captured values at build time.
function Save.rebuildAfterLoad()
    pcall(function() F.buildArrowHud() end)
    pcall(function() Health.build(); Health.setIcons(Health.playerIcon, Health.oppIcon) end)
    pcall(function() Keys.build() end)
    pcall(function() F.setIdleBPM(idleBPM) end)
    pcall(function() F.buildGUI() end)
    pcall(function() F.setTheme(currentThemeName) end)
    pcall(function() Chars.refresh(true) end)
end

function Save.wipe(slot)
    slot = slot or Save.slot
    if not Save.available then return end
    if Save.api.delfile then
        pcall(Save.api.delfile, Save.path(slot))
    else
        pcall(Save.api.write, Save.path(slot), "")   -- no delfile: blank it
    end
    if slot == Save.slot then Save.lastJson = nil; Save.lastSaved = "never" end
    if Save.refreshUI then Save.refreshUI() end
    F.notify("Cleared slot " .. slot, "info")
end

-- Clipboard fallback: works even when the executor has no file access.
function Save.export()
    local json = Save.serialize()
    if not json then F.notify("Couldn't encode settings", "error"); return end
    if Save.api.clip then
        pcall(Save.api.clip, json)
        F.notify("Settings copied to clipboard", "success")
    else
        F.notify("No clipboard access — the text is in the box instead", "warn")
    end
    return json
end

function Save.import(json)
    local data = Save.deserialize(json)
    if not data then F.notify("That text isn't a valid settings export", "error"); return false end
    local _, failed = Save.apply(data)
    Save.rebuildAfterLoad()
    if #failed > 0 then
        F.notify("Imported — skipped: " .. table.concat(failed, ", "), "warn")
    else
        F.notify("Settings imported", "success")
    end
    return true
end

-- Called in the launch sequence BEFORE the GUI is built, so the panel is
-- constructed straight from your saved settings.
function Save.boot()
    Save.resolveApi()
    if not Save.available then
        F.log("no writefile/readfile — saving disabled, clipboard export still works")
        return
    end
    local data, info = Save.read(Save.slot)
    if data then
        local _, failed = Save.apply(data)
        Save.lastJson = info
        Save.lastLoaded = os.date("%H:%M:%S")
        if #failed > 0 then F.log("boot load skipped: " .. table.concat(failed, ", ")) end
    end
end

function Save.startAuto()
    if Save.autoThread then return end
    Save.autoThread = task.spawn(function()
        while F.alive do
            task.wait(Save.interval)
            -- unloaded while asleep: a newer copy owns the save file now
            if not F.alive then break end
            if Save.autoSave and Save.available then
                -- only touch the disk if something actually changed
                local json = Save.serialize()
                if json and json ~= Save.lastJson then Save.write(Save.slot, true) end
            end
        end
    end)
end


-- ============================================================
--  RIDE v4 — hard lock, and what other players see
--
--  Stores your position in the object's own coordinate space and
--  rebuilds your world CFrame from it every frame:
--
--      root.CFrame = object.CFrame * localOffset
--
--  Nothing accumulates, so there's no drift and no error that grows
--  with speed. Walking and jumping both happen in object space too,
--  which is why a jump lands you back on the same spot even at speed.
--
--  Other players see you about one round trip late, while the object
--  keeps moving on their screens. So the pose that's SENT is your spot
--  on the object as it will be by then (Ride.predict), and it's written
--  right before AND right after physics, so the pose that leaves your
--  client is exactly that one, not wherever physics nudged you to.
--  Your own screen keeps the object as it is now.
-- ============================================================
function Ride.buildWind()
    local old = PlayerGui:FindFirstChild("FNFWind")
    if old then old:Destroy() end

    local sg = F.own(Instance.new("ScreenGui"))
    sg.Name = "FNFWind"; sg.IgnoreGuiInset = true
    sg.ResetOnSpawn = false; sg.DisplayOrder = F.silZ(55)
    sg.Enabled = false; sg.Parent = PlayerGui
    Ride.gui = sg

    Ride.streaks = {}
    for i = 1, 26 do
        local s = Instance.new("Frame")
        s.AnchorPoint = Vector2.new(0.5, 0.5)
        s.Size = UDim2.new(0, 2, 0, 70)
        s.BackgroundColor3 = Color3.new(1, 1, 1)
        s.BackgroundTransparency = 1
        s.BorderSizePixel = 0
        s.ZIndex = F.silZ(55); s.Parent = sg
        F.uiCorner(s, UDim.new(1, 0))
        Ride.streaks[i] = { frame = s, ang = math.random() * math.pi * 2,
                            dist = math.random() * 0.5 + 0.2,
                            speed = 0.4 + math.random() * 0.8 }
    end

    Ride.readout = F.makeLabel(sg, "", UDim2.new(0.5, -130, 1, -172),
        UDim2.new(0, 260, 0, 20), Color3.fromRGB(235,235,245), Enum.TextXAlignment.Center, 12)
    Ride.readout.Font = Enum.Font.GothamBold
    Ride.readout.TextStrokeTransparency = 0.5
    Ride.readout.ZIndex = F.silZ(56)
end

-- Is this part part of somebody's character?
local function isCharacterPart(p)
    local m = p:FindFirstAncestorOfClass("Model")
    return m and m:FindFirstChildOfClass("Humanoid") ~= nil
end

-- What raycasts and the picker should never see: you, and the ghost
-- that shows where other players see you.
function Ride.skipList()
    local skip = { character }
    if Ride.viewModel then table.insert(skip, Ride.viewModel) end
    return skip
end

-- Pick the object to lock to: what's under you first, then the nearest part.
function Ride.pick()
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = Ride.skipList()
    local hit = Workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params)
    if hit and hit.Instance and not isCharacterPart(hit.Instance) then
        return hit.Instance
    end

    local op = OverlapParams.new()
    op.FilterType = Enum.RaycastFilterType.Exclude
    op.FilterDescendantsInstances = Ride.skipList()
    local ok, parts = pcall(function()
        return Workspace:GetPartBoundsInRadius(root.Position, Ride.pickRadius, op)
    end)
    if not ok or not parts then return nil end

    local best, bestD = nil, math.huge
    for _, p in ipairs(parts) do
        if p:IsA("BasePart") and not isCharacterPart(p) and p.Transparency < 1 then
            local d = (p.Position - root.Position).Magnitude
            if d < bestD then best, bestD = p, d end
        end
    end
    return best
end

function Ride.jumpVelocity(hum)
    local g = Workspace.Gravity * Ride.gravityScale
    local ok, useJP = pcall(function() return hum.UseJumpPower end)
    if ok and useJP then return hum.JumpPower end
    local okH, h = pcall(function() return hum.JumpHeight end)
    return math.sqrt(2 * g * ((okH and h) or 7.2))
end

-- Borrow the character's own idle, walk, jump and fall animations from its
-- Animate script and play them ourselves, at a priority above the default
-- ones. While you're locked on, the object is moving under you, so the
-- humanoid can decide you're falling and play its falling animation. Ours
-- outrank that, so you look planted on the object instead.
function Ride.stopAnims(fade)
    for _, t in pairs(Ride.tracks or {}) do
        pcall(function() if t.IsPlaying then t:Stop(fade or 0.15) end end)
    end
    Ride.currentAnim = nil
end

function Ride.loadAnims(hum)
    Ride.stopAnims(0)
    Ride.tracks, Ride.currentAnim = {}, nil
    local animate = character and character:FindFirstChild("Animate")
    local animr = hum and hum:FindFirstChildOfClass("Animator")
    if not animate or not animr then return end

    local function load(folderName, preferred)
        local folder = animate:FindFirstChild(folderName)
        if not folder then return nil end
        local anim = folder:FindFirstChild(preferred)
        if not (anim and anim:IsA("Animation")) then anim = folder:FindFirstChildOfClass("Animation") end
        if not anim then return nil end
        local ok, t = pcall(function() return animr:LoadAnimation(anim) end)
        if not ok or not t then return nil end
        t.Priority = Enum.AnimationPriority.Movement
        t.Looped = (folderName ~= "jump")
        return t
    end
    Ride.tracks = {
        idle = load("idle", "Animation1"),
        walk = load("walk", "WalkAnim"),
        jump = load("jump", "JumpAnim"),
        fall = load("fall", "FallAnim"),
    }
end

-- Idle when standing on it, walk when moving, jump then fall in the air.
function Ride.updateAnim(hum, moving)
    local tracks = Ride.tracks
    if not tracks then return end
    local want = "idle"
    if not Ride.grounded then want = (Ride.vy > 0) and "jump" or "fall"
    elseif moving then want = "walk" end
    if not tracks[want] then want = "idle" end
    local t = tracks[want]
    if not t then return end

    if Ride.currentAnim ~= want then
        local old = tracks[Ride.currentAnim]
        if old and old ~= t and old.IsPlaying then old:Stop(0.12) end
        Ride.currentAnim = want
    end
    if not t.IsPlaying then t:Play(0.12) end
    if want == "walk" then t:AdjustSpeed(math.max(hum.WalkSpeed / 16, 0.1)) end
end

-- Ping in milliseconds. MINE reads yours from the network stats Roblox shows
-- on its own performance overlay. AVERAGE also tries to read every other
-- player's ping and averages them all. If other players' pings can't be read
-- here it quietly falls back to yours and reports that, so you always know
-- which one you're getting.
-- Returns: ms, how many players went into it, whether any other player's ping was readable.
function Ride.measurePing()
    local mine
    local ok, v = pcall(function()
        return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    if ok and type(v) == "number" and v > 0 then mine = v end
    if not mine then
        local ok2, p = pcall(function() return LocalPlayer:GetNetworkPing() end)   -- seconds
        if ok2 and type(p) == "number" and p > 0 then mine = p * 1000 end
    end
    if Ride.pingSource ~= "AVERAGE" then return mine, 1, false end

    local sum, n, others = 0, 0, 0
    if mine then sum, n = mine, 1 end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local okp, p = pcall(function() return plr:GetNetworkPing() end)      -- seconds
            if okp and type(p) == "number" and p > 0 and p < 5 then
                sum = sum + p * 1000
                n = n + 1
                others = others + 1
            end
        end
    end
    if n == 0 then return nil, 0, false end
    return sum / n, n, others > 0
end

-- If YOU are simulating the object (you're driving it), your screen and
-- everyone else's agree on where it is, so there's nothing to compensate for.
function Ride.locallyOwned(part)
    if part.Anchored then return false end
    local ok, age = pcall(function() return part.ReceiveAge end)
    return ok and age == 0
end

-- How late other players see you, in seconds: your round trip plus the
-- smoothing delay, times the strength slider, capped. The lead uses this,
-- and so does the check that shows what they see.
function Ride.viewLag()
    return math.min((Ride.pingMs + Ride.extraMs) / 1000 * Ride.pingScale, Ride.maxLead)
end

-- Where you stand on the object, in its own space.
function Ride.offsetCF()
    return CFrame.new(Ride.localPos + Vector3.new(0, Ride.yOff, 0)) * CFrame.Angles(0, Ride.yaw, 0)
end

-- ------------------------------------------------------------
--  ROUTE MEMORY
--  The object's recent path, 30 times a second, in a ring. Trains,
--  lifts, platforms and carts mostly go round the same route. Once it
--  comes back to a spot it's been at before, moving the same way, what
--  it did next last time is a far better guess than a straight line:
--  it already knows the next corner, the next stop and the loop reset.
-- ------------------------------------------------------------
function Ride.routeReset()
    local size = math.max(60, math.floor((Ride.routeSecs or 90) * 30))
    Ride.hist = { t = {}, cf = {}, v = {}, dwell = {}, size = size, head = 1, count = 0 }
    Ride.hLastT, Ride.matchLag, Ride.matchCheckT, Ride.matchSearchT = 0, nil, 0, 0
    Ride.routePeriod = 0
end

-- ring slot of the j-th remembered sample, 1 = oldest
function Ride.hIdx(j)
    local h = Ride.hist
    return ((h.head - h.count + j - 2) % h.size) + 1
end

function Ride.hPush(t, cf, v, dwell)
    local h = Ride.hist
    if not h then return end
    local i = h.head
    h.t[i], h.cf[i], h.v[i], h.dwell[i] = t, cf, v, dwell
    h.head = i % h.size + 1
    h.count = math.min(h.count + 1, h.size)
end

-- The remembered pose and velocity at time t, blended between samples.
function Ride.hAt(t)
    local h = Ride.hist
    if not h or h.count < 2 then return nil end
    local idx = Ride.hIdx
    local lo, hi = 1, h.count
    if t < h.t[idx(lo)] or t > h.t[idx(hi)] then return nil end
    while hi - lo > 1 do
        local mid = math.floor((lo + hi) / 2)
        if h.t[idx(mid)] <= t then lo = mid else hi = mid end
    end
    local a, b = idx(lo), idx(hi)
    local ta, tb = h.t[a], h.t[b]
    local k = (tb > ta) and (t - ta) / (tb - ta) or 0
    return h.cf[a]:Lerp(h.cf[b], k), h.v[a]:Lerp(h.v[b], k)
end

-- Look back for a moment when the object was where it is now, facing and
-- moving the same way (and, if it's standing still, had been standing for
-- as long, so a lift waiting at a floor knows when it leaves). Returns that
-- moment's time, or nil.
function Ride.routeSearch(now, pcf, vel, dwell, lead)
    local h = Ride.hist
    if not h or h.count < 90 then return nil end
    local idx = Ride.hIdx
    local newest = now - math.max(3, lead * 4)    -- an earlier pass, not a moment ago
    local speed = vel.Magnitude
    local posTol = 3 + speed * 0.03
    local velTol = math.max(3, speed * 0.15)
    local look, pos = pcf.LookVector, pcf.Position
    local best, bestCost = nil, 1                  -- every part of the cost has to be under 1
    for j = h.count, 1, -1 do
        local i = idx(j)
        local t = h.t[i]
        if t <= newest then
            local cf = h.cf[i]
            local dp = (cf.Position - pos).Magnitude / posTol
            if dp < 1 then
                local dv = (h.v[i] - vel).Magnitude / velTol
                if dv < 1 then
                    local dr = (1 - cf.LookVector:Dot(look)) / 0.035   -- ~15 degrees
                    local dd = 0
                    if speed < 0.5 then dd = math.abs(h.dwell[i] - dwell) / 0.6 end
                    local cost = math.max(dp, dv, dr, dd)
                    if cost < bestCost then best, bestCost = t, cost end
                end
            end
        end
    end
    return best
end

-- Keeps the match lined up, drops it when the object stops following the
-- remembered route, and looks for a new one twice a second when there's none.
function Ride.routeStep(now, pcf, lead)
    local mode = Ride.guess
    if mode ~= "AUTO" and mode ~= "ROUTE" then
        Ride.matchLag = nil
        return
    end
    if Ride.matchLag and now - Ride.matchCheckT > 0.2 then
        Ride.matchCheckT = now
        local m = now - Ride.matchLag
        local mcf, mv = Ride.hAt(m)
        local ok = false
        if mcf and Ride.hAt(m + lead + 0.1) then
            local speed = Ride.platVel.Magnitude
            ok = (mcf.Position - pcf.Position).Magnitude < 4.5 + speed * 0.05
                and (mv - Ride.platVel).Magnitude < math.max(4.5, speed * 0.25)
        end
        if not ok then Ride.matchLag = nil end
    end
    if not Ride.matchLag and now - Ride.matchSearchT > 0.5 then
        Ride.matchSearchT = now
        local m = Ride.routeSearch(now, pcf, Ride.platVel, Ride.dwell, lead)
        if m then
            Ride.matchLag = now - m
            Ride.matchCheckT = now
            Ride.routePeriod = now - m
        end
    end
end

-- What the object did after the matched moment, replayed from where it is now.
function Ride.predictRoute(pcf, t)
    local m = os.clock() - Ride.matchLag
    local a = Ride.hAt(m)
    local b, bv = Ride.hAt(m + t)
    if not (a and b) then return nil end
    local turn = pcf.Rotation * a.Rotation:Inverse()
    return pcf * (a:Inverse() * b), turn * bv
end

-- Keeps turning at the rate it's turning and speeding up (or braking) at the
-- rate it is, so a car going round a bend is guessed round the bend instead
-- of straight off it.
function Ride.predictCurve(pcf, t)
    local v, w = Ride.platVel, Ride.platAng
    local speed = v.Magnitude
    local wm = w.Magnitude
    local axis = (wm > 1e-4) and (w / wm) or nil
    local acc = (speed > 1) and Ride.accel or 0
    local dir = (speed > 1e-3) and (v / speed) or Vector3.new(0, 0, 0)
    local pos = pcf.Position
    local n = 6
    local h = t / n
    for i = 1, n do
        local s = (i - 0.5) * h
        local d = dir
        if axis then d = CFrame.fromAxisAngle(axis, wm * s) * dir end
        pos = pos + d * (math.max(0, speed + acc * s) * h)
    end
    local rot, dEnd = pcf.Rotation, dir
    if axis then
        local turn = CFrame.fromAxisAngle(axis, wm * t)
        rot = turn * rot
        dEnd = turn * dir
    end
    return CFrame.new(pos) * rot, dEnd * math.max(0, speed + acc * t)
end

-- Where the object will be t seconds from now, and how fast it'll be going.
--   AUTO  : the remembered route when there's a match, the curve otherwise
--   ROUTE : the same (it's the curve until the route has come round once)
--   CURVE : turn and speed-up kept going
--   LINE  : straight on at today's speed and spin (v3's guess)
function Ride.predict(pcf, t)
    local mode = Ride.guess
    if (mode == "AUTO" or mode == "ROUTE") and Ride.matchLag then
        local cf, v = Ride.predictRoute(pcf, t)
        if cf then return cf, v end
    end
    if mode == "LINE" then
        local rot = pcf.Rotation
        local w = Ride.platAng
        local a = w.Magnitude * t
        if a > 1e-5 then rot = CFrame.fromAxisAngle(w.Unit, a) * rot end
        return CFrame.new(pcf.Position + Ride.platVel * t) * rot, Ride.platVel
    end
    return Ride.predictCurve(pcf, t)
end

-- What it says the object is moved by. Only a guess for anchored ones:
-- an object moved on your own screen changes every frame, one moved by the
-- server changes whenever an update comes in and sits still in between.
Ride.kindText = {
    YOU     = "you're simulating it, so everyone sees it in step with you",
    PHYSICS = "physics, sent by the server or another player",
    SERVER  = "looks moved by a server script",
    LOCAL   = "looks animated on your screen by the game — fine if everyone's game animates it too; if only yours does, others can't see it at all",
    STILL   = "standing still",
}

function Ride.kindStep(part, moved)
    if Ride.locallyOwned(part) then Ride.kind = "YOU"; return end
    local okG, grounded = pcall(function() return part:IsGrounded() end)
    if not (okG and grounded) then Ride.kind = "PHYSICS"; return end
    if Ride.smooth < 0.5 then
        if Ride.kind == "" then Ride.kind = "STILL" end
        return
    end
    Ride.kFrames = Ride.kFrames + 1
    if not moved then Ride.kStale = Ride.kStale + 1 end
    if Ride.kFrames >= 30 then
        Ride.kind = (Ride.kStale / Ride.kFrames > 0.2) and "SERVER" or "LOCAL"
    end
    if Ride.kFrames > 240 then Ride.kFrames, Ride.kStale = Ride.kFrames / 2, Ride.kStale / 2 end
end

-- ------------------------------------------------------------
--  NO COLLIDE while locked: your pose is written every frame, so collisions
--  can only get in the way. They push the pose physics hands to the network
--  off from the one we wrote, and if the object is loose and yours to
--  simulate, they shove the object itself around. Your parts stop colliding
--  on your client only; they still touch things (CanTouch is left alone).
-- ------------------------------------------------------------
function Ride.collideBegin()
    Ride.collideParts = {}
    if not Ride.noCollide or not character then return end
    for _, d in ipairs(character:GetDescendants()) do
        if d:IsA("BasePart") and d.CanCollide then table.insert(Ride.collideParts, d) end
    end
end

function Ride.collideStep()
    if not Ride.noCollide or not Ride.collideParts then return end
    for _, p in ipairs(Ride.collideParts) do
        if p.Parent and p.CanCollide then p.CanCollide = false end
    end
end

function Ride.collideEnd()
    for _, p in ipairs(Ride.collideParts or {}) do
        pcall(function() if p.Parent then p.CanCollide = true end end)
    end
    Ride.collideParts = nil
end

-- ------------------------------------------------------------
--  SEATS
--  If the object has a free seat, sitting in it is the one way to be on it
--  EXACTLY for everyone: the game welds you to it on its side, so you move
--  as part of the object on every screen, with no guessing. You're put on
--  the seat and the game's own seat sits you; if it doesn't within a moment
--  and a half (the game turned it off, or keeps seats to itself), it falls
--  back to the standing lock. Passenger seats only, never a driver's seat.
-- ------------------------------------------------------------
function Ride.findSeat(part)
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local ok, parts = pcall(function() return part:GetConnectedParts(true) end)
    if not ok or type(parts) ~= "table" then return nil end
    if part:IsA("Seat") then table.insert(parts, 1, part) end
    local best, bestD = nil, 80
    for i, p in ipairs(parts) do
        if i > 4000 then break end
        if p:IsA("Seat") and not p.Disabled and p.Occupant == nil then
            local d = (p.Position - root.Position).Magnitude
            if d < bestD then best, bestD = p, d end
        end
    end
    return best
end

-- Returns true while the seat is in charge (trying or sitting).
function Ride.seatStep(now, hum, root)
    if Ride.seat then
        if not Ride.seat.Parent then Ride.unlock("the seat is gone"); return true end
        if hum.SeatPart ~= Ride.seat then Ride.unlock("you got up"); return true end
        return true
    end
    local seat = Ride.seatTry
    if not seat or not seat.Parent then
        Ride.seatTry = nil
        F.notify("The seat is gone — standing lock instead", "warn")
        return false
    end
    if seat.Occupant ~= nil and seat.Occupant ~= hum then
        Ride.seatTry = nil
        F.notify("Someone took the seat — standing lock instead", "warn")
        return false
    end
    if hum.SeatPart == seat then
        Ride.seat, Ride.seatTry = seat, nil
        Ride.stopAnims(0.1)           -- the game's own sitting animation takes over
        Ride.collideEnd()
        if Ride.refreshUI then Ride.refreshUI() end
        F.notify("Sitting on it — the game holds you there, so everyone sees you on it exactly", "success")
        return true
    end
    if now > Ride.seatUntil then
        Ride.seatTry = nil
        F.notify("The seat didn't take you — standing lock instead", "warn")
        return false
    end
    -- stand right on it so the touch reaches the game's seat
    root.CFrame = seat.CFrame * CFrame.new(0, seat.Size.Y / 2 + 1, 0)
    root.AssemblyLinearVelocity = Ride.platVel
    return true
end

-- ------------------------------------------------------------
--  WHAT OTHERS SEE
--  Every pose that's sent is logged for a moment and a half. Other players
--  see the one sent viewLag() ago while the object, on their screens, is
--  where yours is now. So that logged pose, drawn in your world, is where
--  they see you on the object, and its distance from where you meant to be
--  is how far off the guess was. If the object is yours to simulate they
--  get both late by the same amount, so they see you exactly on it.
-- ------------------------------------------------------------
function Ride.buildView()
    if Ride.viewModel and Ride.viewModel.Parent then return Ride.viewModel end
    local char = character
    if not char then return nil end
    local wasArch = char.Archivable
    if not wasArch then char.Archivable = true end
    local ok, clone = pcall(function() return char:Clone() end)
    if not wasArch then char.Archivable = wasArch end
    if not ok or not clone then return nil end

    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Humanoid") or d:IsA("Sound")
            or d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam")
            or d:IsA("BillboardGui") or d:IsA("ForceField") or d:IsA("Highlight") then
            d:Destroy()
        end
    end
    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored = true
            d.CanCollide = false
            pcall(function() d.CanQuery = false; d.CanTouch = false end)
            d.CastShadow = false
        end
    end
    local hl = Instance.new("Highlight")
    hl.FillColor = Color3.fromRGB(120, 220, 255)
    hl.OutlineColor = Color3.fromRGB(200, 245, 255)
    hl.FillTransparency = 0.55
    hl.OutlineTransparency = 0.1
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = clone
    clone.Name = "FNFRideView"
    clone.Parent = Workspace.CurrentCamera or Workspace
    Ride.viewModel = F.own(clone)
    if Ride.wallParams then Ride.wallParams.FilterDescendantsInstances = Ride.skipList() end
    return clone
end

function Ride.dropView()
    if Ride.viewModel then pcall(function() Ride.viewModel:Destroy() end) end
    Ride.viewModel = nil
    Ride.sentLog = {}
    Ride.viewGap = 0
    if Ride.wallParams then Ride.wallParams.FilterDescendantsInstances = Ride.skipList() end
end

function Ride.logSent(cf, off)
    local log = Ride.sentLog
    local now = os.clock()
    log[#log + 1] = { t = now, cf = cf, off = off }
    while log[1] and log[1].t < now - 1.5 do table.remove(log, 1) end
end

function Ride.viewStep(now, pcf, dt)
    if not Ride.showView or Ride.seat or Ride.seatTry then
        if Ride.viewModel then Ride.dropView() end
        return
    end
    local log = Ride.sentLog
    local at = now - Ride.viewLag()
    local e
    for i = #log, 1, -1 do
        if log[i].t <= at then e = log[i]; break end
    end
    if not e then return end
    local ghost = Ride.buildView()
    if not ghost then return end
    local seen = e.cf
    if Ride.locallyOwned(Ride.part) then seen = pcf * e.off end
    local gap = (seen.Position - (pcf * e.off).Position).Magnitude
    Ride.viewGap = Ride.viewGap + (gap - Ride.viewGap) * (1 - math.exp(-6 * dt))
    pcall(function() ghost:PivotTo(seen) end)
end

-- ------------------------------------------------------------
--  WRITING YOUR POSE
--  Your position AND velocity, from the object-space state.
--
--  The root is NOT anchored. An anchored part moved by a client script never
--  replicates, so other players saw you frozen where you locked on while the
--  object drove away. Unanchored, you keep network ownership and this position
--  is what gets sent to everyone. Velocity is written too, so other players
--  interpolate you smoothly instead of seeing you jump between updates.
--
--  forReplication: the pose to send (the object where it will be by the time
--  they see you). Otherwise: the object as it is now, for your own screen.
--  Three writes a frame: before the camera (yours), before physics (so
--  physics starts from the sent pose), after physics (so what's sent is
--  exactly the sent pose, not wherever gravity, the humanoid or a bump put
--  you). Each only writes state, so repeating them does no harm.
-- ------------------------------------------------------------
function Ride.apply(forReplication)
    if not Ride.enabled or Ride.seat or Ride.seatTry then return nil end
    local part = Ride.part
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not part or not part.Parent or not root then return nil end
    local pcf = part.CFrame

    local base, baseVel = pcf, Ride.platVel
    if forReplication and Ride.leadTime > 0 then
        base, baseVel = Ride.predict(pcf, Ride.leadTime)
    end
    local off = Ride.offsetCF()
    local cf = base * off
    root.CFrame = cf

    -- Velocity of the exact spot you're standing on (spin included), so the
    -- smoothing on other screens carries you around a turn between updates
    -- instead of sliding you off in a straight line.
    local r = cf.Position - base.Position
    root.AssemblyLinearVelocity = baseVel + Ride.platAng:Cross(r) + Ride.walkVel + base.UpVector * Ride.vy
    root.AssemblyAngularVelocity = Ride.platAng
    return cf, off
end

function Ride.afterPhysics()
    local cf, off = Ride.apply(true)
    if cf and Ride.showView then Ride.logSent(cf, off) end
end

function Ride.step(dt)
    local part = Ride.part
    local char = character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not part or not part.Parent or not root or not hum then
        Ride.unlock("lost the object")
        return
    end
    local realDt = math.max(dt, 1/480)
    dt = math.clamp(dt, 1/240, 1/20)
    local now = os.clock()
    local pcf = part.CFrame

    -- ---- what the object is doing (real frame time, so a hitch reads right) ----
    local vel, ang = Vector3.new(0, 0, 0), Vector3.new(0, 0, 0)
    local moved = false
    if Ride.lastCF then
        local d = pcf.Position - Ride.lastCF.Position
        moved = d.Magnitude > 1e-4 or pcf.LookVector:Dot(Ride.lastCF.LookVector) < 0.9999999
        vel = d / realDt
        local okA, axis, angle = pcall(function()
            return (pcf.Rotation * Ride.lastCF.Rotation:Inverse()):ToAxisAngle()
        end)
        if okA and angle == angle and math.abs(angle) > 1e-6 then ang = axis * (angle / realDt) end
    end
    Ride.lastCF = pcf
    Ride.lastPos = pcf.Position
    if vel.Magnitude > 2000 or ang.Magnitude > 60 then          -- a teleport, not motion
        vel, ang = Vector3.new(0, 0, 0), Vector3.new(0, 0, 0)
    end

    -- smoothed, so noisy per-frame speed doesn't shake what gets replicated
    local oldSpeed = Ride.platVel.Magnitude
    Ride.platVel = Ride.platVel:Lerp(vel, 1 - math.exp(-14 * dt))
    Ride.platAng = Ride.platAng:Lerp(ang, 1 - math.exp(-14 * dt))
    Ride.turnDeg = math.deg(Ride.platAng.Magnitude)
    local newSpeed = Ride.platVel.Magnitude
    Ride.accel = Ride.accel + (math.clamp((newSpeed - oldSpeed) / dt, -150, 150) - Ride.accel)
        * (1 - math.exp(-4 * dt))
    if vel.Magnitude < 0.3 and newSpeed < 0.5 then Ride.dwell = Ride.dwell + realDt else Ride.dwell = 0 end

    if Ride.hist and now - Ride.hLastT >= 1/30 then
        Ride.hLastT = now
        Ride.hPush(now, pcf, Ride.platVel, Ride.dwell)
    end
    Ride.kindStep(part, moved)

    -- ---- ping, and how far ahead the sent pose goes ----
    local clk = now
    if clk - Ride.lastPingT > 0.25 then
        Ride.lastPingT = clk
        local ms, cnt, others = Ride.measurePing()
        if ms then
            Ride.pingMs = (Ride.pingMs <= 0) and ms or (Ride.pingMs * 0.7 + ms * 0.3)
            Ride.pingCount, Ride.pingOthers = cnt, others
        end
        if Ride.pingSource == "AVERAGE" and not others and not Ride.warnedOthers
            and #Players:GetPlayers() > 1 then
            Ride.warnedOthers = true
            F.notify("Can't read other players' pings in this game — using yours only", "warn")
        end
    end
    local want = 0
    if Ride.pingComp and not Ride.locallyOwned(part) then want = Ride.viewLag() end
    -- eased, so a ping change doesn't jump you along the object on their screens
    if Ride.leadFresh then
        Ride.leadTime, Ride.leadFresh = want, false
    else
        Ride.leadTime = Ride.leadTime + (want - Ride.leadTime) * (1 - math.exp(-4 * dt))
    end
    Ride.leadStuds = (Ride.platVel * Ride.leadTime).Magnitude
    Ride.routeStep(now, pcf, Ride.leadTime)

    -- ---- the seat, when there is one ----
    local seated = false
    if Ride.seat or Ride.seatTry then
        seated = Ride.seatStep(now, hum, root)
        if not Ride.enabled then return end
    end

    local moving = false
    if not seated then
        -- ---- walking, done in the object's own space ----
        Ride.walkVel = Vector3.new(0, 0, 0)
        local md = hum.MoveDirection
        if Ride.walkWith and md.Magnitude > 0.05 then
            local lm = pcf:VectorToObjectSpace(md)
            lm = Vector3.new(lm.X, 0, lm.Z)
            if lm.Magnitude > 1e-3 then
                local speed = hum.WalkSpeed * math.min(md.Magnitude, 1)
                local stepV = lm.Unit * speed * dt
                -- walls on the object stop you; you slide along them
                if Ride.walls and Ride.wallParams and stepV.Magnitude > 1e-4 then
                    local from = (pcf * Ride.offsetCF()).Position
                    local worldStep = pcf:VectorToWorldSpace(stepV)
                    local hit = Workspace:Raycast(from, worldStep.Unit * (worldStep.Magnitude + 1.3), Ride.wallParams)
                    if hit and math.abs(hit.Normal.Y) < 0.7 then
                        local n = pcf:VectorToObjectSpace(hit.Normal)
                        n = Vector3.new(n.X, 0, n.Z)
                        if n.Magnitude > 1e-3 then
                            n = n.Unit
                            local into = stepV:Dot(n)
                            if into < 0 then stepV = stepV - n * into end
                        end
                    end
                end
                Ride.localPos = Ride.localPos + stepV
                Ride.yaw = math.atan2(-lm.X, -lm.Z)
                Ride.walkVel = pcf:VectorToWorldSpace(stepV / dt)
                moving = true
            end
        end

        -- ---- jump arc, also in object space ----
        if not Ride.grounded then
            Ride.vy = Ride.vy - Workspace.Gravity * Ride.gravityScale * dt
            Ride.yOff = Ride.yOff + Ride.vy * dt
            if Ride.yOff <= 0 then
                Ride.yOff, Ride.vy, Ride.grounded = 0, 0, true
            end
        end

        -- ---- keep you on the surface ----
        if Ride.clampEdges then
            local half = part.Size / 2
            local mx = math.max(0, half.X - Ride.edgeMargin)
            local mz = math.max(0, half.Z - Ride.edgeMargin)
            Ride.localPos = Vector3.new(
                math.clamp(Ride.localPos.X, -mx, mx),
                Ride.localPos.Y,
                math.clamp(Ride.localPos.Z, -mz, mz))
        end

        -- ---- animation: idle on it, walk when moving, jump / fall in the air ----
        Ride.updateAnim(hum, moving)
        Ride.apply(false)
    end

    -- ---- effects ----
    local accel = (vel - Ride.lastVel) / dt
    Ride.lastVel = vel
    Ride.lateralG = Ride.lateralG + ((accel:Dot(root.CFrame.RightVector) / 60) - Ride.lateralG)
        * (1 - math.exp(-8 * dt))

    Ride.speed = vel.Magnitude
    Ride.smooth = Ride.smooth + (Ride.speed - Ride.smooth) * (1 - math.exp(-6 * dt))

    local t = math.clamp((Ride.smooth - Ride.minSpeed) / math.max(1, Ride.maxSpeedAt - Ride.minSpeed), 0, 1)
    FNFCamera.rideShake = Ride.shake and (t * Ride.shakeScale) or 0
    FNFCamera.rideFov   = Ride.speedFov and (t * 14) or 0
    FNFCamera.rideLean  = Ride.gLean and math.clamp(Ride.lateralG * 6 * Ride.leanScale, -9, 9) or 0

    if Ride.gui then
        local show = Ride.wind and t > 0.02
        Ride.gui.Enabled = true
        for _, st in ipairs(Ride.streaks) do
            if show then
                st.dist = st.dist + dt * st.speed * (0.6 + t * 4.5)
                if st.dist > 1.15 then
                    st.dist = 0.05 + math.random() * 0.1
                    st.ang = math.random() * math.pi * 2
                end
                local f = st.frame
                f.Position = UDim2.new(0.5 + math.cos(st.ang) * st.dist * 0.75, 0,
                                       0.5 + math.sin(st.ang) * st.dist * 0.75, 0)
                f.Rotation = math.deg(st.ang) + 90
                f.Size = UDim2.new(0, 2, 0, 30 + t * 130 * st.speed)
                f.BackgroundTransparency = math.clamp(1 - t * 0.85 * Ride.windScale, 0, 1)
            else
                st.frame.BackgroundTransparency = 1
            end
        end
        if Ride.readout then
            local how = Ride.seat and "SEATED" or (Ride.seatTry and "SITTING DOWN")
                or (Ride.matchLag and "ROUTE") or Ride.guess
            Ride.readout.Text = string.format("LOCKED  %.0f studs/s  ·  %s", Ride.smooth, how)
        end
    end

    -- ---- the ghost that shows what other players see ----
    Ride.viewStep(now, pcf, dt)
end

function Ride.lock()
    if Fly.enabled then Fly.stop("ride lock took over") end
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return false end

    local part = Ride.pick()
    if not part then
        F.notify("Nothing to lock to — stand on it or get close", "warn")
        return false
    end

    -- capture where we are relative to it, right now
    local rel = part.CFrame:ToObjectSpace(root.CFrame)
    Ride.part = part
    Ride.localPos = rel.Position
    local look = rel.LookVector
    Ride.yaw = math.atan2(-look.X, -look.Z)
    Ride.yOff, Ride.vy, Ride.grounded = 0, 0, true
    Ride.lastPos, Ride.lastVel = part.Position, Vector3.new(0, 0, 0)
    Ride.speed, Ride.smooth, Ride.lateralG = 0, 0, 0

    -- Never anchor: it would stop your position replicating (other players
    -- would see you floating where you locked on). Instead we rewrite position
    -- and velocity every frame before physics, and stop the humanoid from
    -- turning you or tripping over at speed.
    Ride.wasAnchored = root.Anchored
    root.Anchored = false
    Ride.savedAutoRotate = hum.AutoRotate
    hum.AutoRotate = false
    Ride.savedStates = {}
    for _, st in ipairs({ Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll,
                          Enum.HumanoidStateType.Freefall }) do
        local ok, on = pcall(function() return hum:GetStateEnabled(st) end)
        Ride.savedStates[st] = (not ok) or on
        pcall(function() hum:SetStateEnabled(st, false) end)
    end
    Ride.platVel, Ride.walkVel = Vector3.new(0, 0, 0), Vector3.new(0, 0, 0)
    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)   -- drop any falling pose
    Ride.leadTime, Ride.leadFresh, Ride.lastCF = 0, true, part.CFrame
    Ride.platAng, Ride.turnDeg = Vector3.new(0, 0, 0), 0
    Ride.warnedOthers, Ride.lastPingT = false, 0
    Ride.accel, Ride.dwell = 0, 0
    Ride.kind, Ride.kFrames, Ride.kStale = "", 0, 0
    Ride.sentLog, Ride.viewGap = {}, 0

    -- the route is kept when you lock back onto the same object
    if Ride.histPart ~= part or not Ride.hist then
        Ride.routeReset()
        Ride.histPart = part
    end
    Ride.matchLag = nil

    Ride.wallParams = RaycastParams.new()
    Ride.wallParams.FilterType = Enum.RaycastFilterType.Exclude
    Ride.wallParams.FilterDescendantsInstances = Ride.skipList()
    pcall(function() Ride.wallParams.RespectCanCollide = true end)

    Ride.loadAnims(hum)
    Ride.collideBegin()

    -- a free seat beats every guess (see SEATS)
    Ride.seat, Ride.seatTry = nil, nil
    if Ride.seatFirst then
        local seat = Ride.findSeat(part)
        if seat then
            Ride.seatTry, Ride.seatUntil = seat, os.clock() + 1.5
        end
    end

    if Ride.jumpConn then Ride.jumpConn:Disconnect() end
    Ride.jumpConn = F.own(UserInputService.JumpRequest:Connect(function()
        if Ride.enabled and Ride.jumpWith and Ride.grounded and not (Ride.seat or Ride.seatTry) then
            local h = character and character:FindFirstChildOfClass("Humanoid")
            if h then
                Ride.vy = Ride.jumpVelocity(h)
                Ride.grounded = false
            end
        end
    end))

    if not Ride.gui or not Ride.gui.Parent then Ride.buildWind() end
    -- run just before the camera, so the camera always sees our final position
    pcall(function() RunService:UnbindFromRenderStep(Ride.bindName) end)
    RunService:BindToRenderStep(Ride.bindName, Enum.RenderPriority.Camera.Value - 1,
        function(dt) Ride.step(dt) end)
    -- right before physics: the sent pose, so physics starts from it
    if Ride.stepConn then Ride.stepConn:Disconnect() end
    Ride.stepConn = F.own(RunService.Stepped:Connect(function()
        Ride.collideStep()
        Ride.apply(true)
    end))
    -- right after physics: the sent pose again, exactly, for the network
    if Ride.postConn then Ride.postConn:Disconnect() end
    Ride.postConn = F.own(RunService.Heartbeat:Connect(function() Ride.afterPhysics() end))

    Ride.enabled = true
    if Ride.refreshUI then Ride.refreshUI() end
    F.notify((Ride.seatTry and "Sitting down on " or "Locked to ") .. part.Name, "success")
    return true
end

function Ride.unlock(reason)
    if not Ride.enabled then return end
    Ride.enabled = false
    pcall(function() RunService:UnbindFromRenderStep(Ride.bindName) end)
    if Ride.jumpConn then Ride.jumpConn:Disconnect(); Ride.jumpConn = nil end
    if Ride.stepConn then Ride.stepConn:Disconnect(); Ride.stepConn = nil end
    if Ride.postConn then Ride.postConn:Disconnect(); Ride.postConn = nil end
    Ride.collideEnd()
    Ride.dropView()

    local wasSeated = Ride.seat ~= nil
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    if wasSeated and hum and hum.SeatPart == Ride.seat then
        pcall(function() hum.Sit = false end)
        pcall(function() hum.Jump = true end)      -- gets you out of the seat
    end
    Ride.seat, Ride.seatTry = nil, nil

    local root = character and character:FindFirstChild("HumanoidRootPart")
    if root then
        root.Anchored = Ride.wasAnchored
        -- leave with the object's velocity so letting go doesn't stop you dead
        if not root.Anchored and not wasSeated then
            pcall(function() root.AssemblyLinearVelocity = Ride.lastVel end)
        end
    end
    if hum then
        if Ride.savedAutoRotate ~= nil then hum.AutoRotate = Ride.savedAutoRotate end
        for st, on in pairs(Ride.savedStates or {}) do
            pcall(function() hum:SetStateEnabled(st, on) end)
        end
    end
    Ride.savedAutoRotate, Ride.savedStates = nil, nil
    Ride.platVel, Ride.walkVel = Vector3.new(0, 0, 0), Vector3.new(0, 0, 0)

    Ride.stopAnims(0.2)
    Ride.tracks = nil
    Ride.leadTime, Ride.leadStuds, Ride.lastCF = 0, 0, nil
    Ride.platAng, Ride.turnDeg = Vector3.new(0, 0, 0), 0
    Ride.matchLag, Ride.wallParams = nil, nil

    if Ride.gui then Ride.gui.Enabled = false end
    FNFCamera.rideShake, FNFCamera.rideFov, FNFCamera.rideLean = 0, 0, 0
    Ride.part = nil

    if Ride.refreshUI then Ride.refreshUI() end
    F.notify(reason and ("Unlocked — " .. reason) or "Unlocked", "info")
end

-- Kept so the keybind and older call sites keep working.
function Ride.setEnabled(state)
    if state then Ride.lock() else Ride.unlock() end
end

-- ============================================================
--  FLY
--  Your own character only. A LinearVelocity in your root holds you
--  up and carries you, so you still hit walls, floors and ceilings:
--  nothing goes through anything. You keep network ownership of your
--  character, so everyone sees you fly.
--
--  You hover at a spot (Fly.home). The move keys move that spot;
--  Space and Ctrl take it up and down. Every pose moves you a few
--  studs its way:
--    FACE TO FACE: you face your opponent (or the nearest player);
--                  LEFT and RIGHT step you to your own left and right
--    SIDE TO SIDE: you turn to the screen, like an FNF stage; LEFT and
--                  RIGHT go screen left and screen right
--  UP and DOWN go up and down in both. With RETURN on, you drift back
--  to your spot once you let go of the note; with it off, every pose
--  moves your spot for good.
-- ============================================================
Fly.UP = Vector3.new(0, 1, 0)
Fly.ZERO = Vector3.new(0, 0, 0)

-- Who you face in FACE TO FACE: your opponent, else the nearest player close by.
function Fly.partner()
    local function rootOf(plr)
        local c = plr and plr.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end
    local r = rootOf(currentTarget)
    if r then return r, currentTarget.DisplayName end
    local mine = Fly.root
    if not mine then return nil, nil end
    local best, bestD, bestName = nil, 60, nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local pr = rootOf(p)
            if pr then
                local d = (pr.Position - mine.Position).Magnitude
                if d < bestD then best, bestD, bestName = pr, d, p.DisplayName end
            end
        end
    end
    return best, bestName
end

-- Which way you face, and which way a RIGHT pose takes you (both flat).
function Fly.frame()
    local cam = Workspace.CurrentCamera
    local cl = cam and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
    local flat = Vector3.new(cl.X, 0, cl.Z)
    flat = (flat.Magnitude > 1e-3) and flat.Unit or Vector3.new(0, 0, -1)
    if Fly.layout == "SIDE" and not Air.on then
        -- facing the screen; RIGHT is screen right, the camera's right
        return -flat, flat:Cross(Fly.UP)
    end
    local face = flat
    local pr = Fly.partnerRoot
    if pr and pr.Parent and Fly.root then
        local d = pr.Position - Fly.root.Position
        d = Vector3.new(d.X, 0, d.Z)
        if d.Magnitude > 0.5 then face = d.Unit end
    end
    return face, face:Cross(Fly.UP)            -- RIGHT is your own right
end

function Fly.dirVec(dir)
    if dir == "UP" then return Fly.UP end
    if dir == "DOWN" then return -Fly.UP end
    local _, right = Fly.frame()
    if dir == "LEFT" then return -right end
    if dir == "RIGHT" then return right end
    return nil
end

function Fly.onPose(dir)
    if not (Fly.enabled and Fly.poseMove and Fly.home) then return end
    local step = Fly.dirVec(dir)
    if not step then return end
    local now = os.clock()
    -- cutting into another pose: its move (or its way back) is still going,
    -- or its note is still held
    local cut = (now - Fly.lastPose < Fly.poseTime * 1.2) or next(Fly.held) ~= nil
        or (Fly.returnHome and Fly.retOff.Magnitude > 0.05)
    if Fly.snapCut and cut then Fly.snapPending = true end
    Fly.held[dir] = true
    Fly.lastPose = now
    if Fly.returnHome then
        local o = Fly.retOff + step * Fly.poseDist
        local cap = Fly.poseDist * 2           -- mashing one way doesn't send you off for miles
        if o.Magnitude > cap then o = o.Unit * cap end
        Fly.retOff = o
    else
        Fly.home = Fly.home + step * Fly.poseDist
    end
end

function Fly.onRelease(dir)
    Fly.held[dir] = nil
end

-- SNAP WHEN CUT: straight to the new spot, no glide. Still stops short
-- of a wall in the way, so it never puts you inside anything.
function Fly.snapTo(root, goal)
    local from = root.Position
    local d = goal - from
    if d.Magnitude < 1e-3 then return from end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character }
    pcall(function() params.RespectCanCollide = true end)
    local to = goal
    local hit = Workspace:Raycast(from, d, params)
    if hit then
        local gap = (hit.Position - from).Magnitude
        to = from + d.Unit * math.max(0, gap - 2)
    end
    root.CFrame = CFrame.new(to) * root.CFrame.Rotation
    root.AssemblyLinearVelocity = Fly.ZERO
    return to
end

-- Your character's own swim animations (R15 has them), else its idle.
function Fly.stopAnims()
    for _, t in pairs(Fly.tracks or {}) do
        pcall(function() if t.IsPlaying then t:Stop(0.2) end end)
    end
    Fly.curAnim = nil
end

function Fly.loadAnims(hum)
    Fly.stopAnims()
    Fly.tracks, Fly.curAnim = {}, nil
    local animate = character and character:FindFirstChild("Animate")
    local animr = hum and hum:FindFirstChildOfClass("Animator")
    if not animate or not animr then return end
    local function load(folderName, preferred)
        local folder = animate:FindFirstChild(folderName)
        local anim = folder and (folder:FindFirstChild(preferred) or folder:FindFirstChildOfClass("Animation"))
        if not (anim and anim:IsA("Animation")) then return nil end
        local ok, t = pcall(function() return animr:LoadAnimation(anim) end)
        if not ok or not t then return nil end
        t.Priority = Enum.AnimationPriority.Movement   -- under your poses, over the default ones
        t.Looped = true
        return t
    end
    Fly.tracks = {
        still  = load("swimidle", "SwimIdle") or load("idle", "Animation1"),
        moving = load("swim", "Swim") or load("idle", "Animation1"),
    }
end

function Fly.animStep(speed)
    if not Fly.anims then
        if Fly.curAnim then Fly.stopAnims() end
        return
    end
    local tracks = Fly.tracks
    if not tracks then return end
    local want = (speed > 4) and "moving" or "still"
    local t = tracks[want]
    if not t then return end
    if Fly.curAnim ~= want then
        local old = Fly.curAnim and tracks[Fly.curAnim]
        if old and old ~= t and old.IsPlaying then old:Stop(0.25) end
        Fly.curAnim = want
    end
    if not t.IsPlaying then t:Play(0.25) end
end

function Fly.start()
    if Fly.enabled then return true end
    local char = character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health <= 0 then
        F.notify("No character to fly with", "warn")
        return false
    end
    if Ride.enabled then Ride.unlock("flying instead") end

    local att = Instance.new("Attachment")
    att.Name = "FNFFlyAtt"
    att.Parent = root
    local lv = Instance.new("LinearVelocity")
    lv.Name = "FNFFly"
    lv.Attachment0 = att
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    lv.MaxForce = math.max(root.AssemblyMass, 1) * Workspace.Gravity * 40
    lv.VectorVelocity = Fly.ZERO
    lv.Parent = root

    Fly.root, Fly.hum, Fly.att, Fly.lv = root, hum, att, lv
    Fly.savedAuto = hum.AutoRotate
    hum.AutoRotate = false
    hum.PlatformStand = true
    Fly.home = root.Position + Vector3.new(0, 2, 0)     -- a little lift-off
    Fly.pos = root.Position
    Fly.retOff, Fly.held, Fly.tilt, Fly.lastPose = Fly.ZERO, {}, Fly.ZERO, 0
    Fly.snapPending = false
    local look = root.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    Fly.rot = CFrame.lookAt(Fly.ZERO, (flat.Magnitude > 1e-3) and flat.Unit or Vector3.new(0, 0, -1))
    Fly.partnerT, Fly.partnerRoot, Fly.facing = 0, nil, ""
    Fly.loadAnims(hum)

    Fly.enabled = true
    if Fly.conn then Fly.conn:Disconnect() end
    Fly.conn = F.own(RunService.RenderStepped:Connect(function(dt)
        local ok, err = pcall(Fly.step, dt)
        if not ok then
            F.log("fly: " .. tostring(err))
            Fly.stop("something went wrong")
        end
    end))
    if Fly.refreshUI then Fly.refreshUI() end
    F.notify("Flying — move keys to fly, Space up, Ctrl down, your poses move you", "success")
    return true
end

function Fly.stop(reason, limp)
    if not Fly.enabled then return end
    Fly.enabled = false
    if Air.on then Air.stop(reason or "you landed") end
    if Fly.conn then Fly.conn:Disconnect(); Fly.conn = nil end
    pcall(function() if Fly.lv then Fly.lv:Destroy() end end)
    pcall(function() if Fly.att then Fly.att:Destroy() end end)
    Fly.lv, Fly.att = nil, nil
    Fly.stopAnims()
    local hum, root = Fly.hum, Fly.root
    if limp and Air.limpFall(hum, root, Fly.savedAuto) then
        hum, root = nil, nil      -- KO'd: you fall limp and get up once you land
    end
    if hum and hum.Parent then
        pcall(function()
            hum.PlatformStand = false
            if Fly.savedAuto ~= nil then hum.AutoRotate = Fly.savedAuto end
            hum:ChangeState(Enum.HumanoidStateType.Freefall)    -- falls and lands normally
        end)
    end
    if root and root.Parent then
        pcall(function()
            -- stand up straight again
            local look = root.CFrame.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            if flat.Magnitude > 1e-3 then root.CFrame = CFrame.lookAt(root.Position, root.Position + flat) end
            root.AssemblyAngularVelocity = Fly.ZERO
        end)
    end
    Fly.root, Fly.hum, Fly.savedAuto, Fly.home, Fly.pos = nil, nil, nil, nil, nil
    Fly.partnerRoot, Fly.facing = nil, ""
    if Fly.refreshUI then Fly.refreshUI() end
    F.notify(reason and ("Stopped flying — " .. reason) or "Stopped flying", "info")
end

function Fly.toggle()
    if Fly.enabled then Fly.stop() else Fly.start() end
end

function Fly.step(dt)
    local root, hum, lv = Fly.root, Fly.hum, Fly.lv
    if not (root and root.Parent and hum and hum.Parent) or hum.Health <= 0 then
        Fly.stop("lost your character")
        return
    end
    if not (lv and lv.Parent) then
        Fly.stop("the game removed the fly force")
        return
    end
    dt = math.clamp(dt, 1/240, 1/15)
    local now = os.clock()
    if not hum.PlatformStand then hum.PlatformStand = true end   -- the game may switch it back

    if now - Fly.partnerT > 0.25 then
        Fly.partnerT = now
        local r, name = Fly.partner()
        Fly.partnerRoot, Fly.facing = r, name or ""
    end
    local face = Fly.frame()
    if Air.on then Air.step(dt, now) end

    -- move keys move the spot you hover at; Space and Ctrl take it up and down
    local move = Fly.ZERO
    local md = hum.MoveDirection
    local cam = Workspace.CurrentCamera
    if md.Magnitude > 0.05 then
        move = md
        if Fly.lookFly and cam then
            local cl = cam.CFrame.LookVector
            local flat = Vector3.new(cl.X, 0, cl.Z)
            if flat.Magnitude > 1e-3 then
                flat = flat.Unit
                local cr = flat:Cross(Fly.UP)
                move = cl * md:Dot(flat) + cr * md:Dot(cr)     -- forward goes where you look
            end
        end
    end
    if not UserInputService:GetFocusedTextBox() then
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) or (UserInputService.TouchEnabled and hum.Jump) then
            move = move + Fly.UP
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Fly.UP end
    end
    if move.Magnitude > 1 then move = move.Unit end
    if Air.ko then move = Fly.ZERO end     -- KO'd: you can't fly anywhere
    Fly.home = Fly.home + move * math.clamp(Fly.speed, 2, 40) * dt

    -- after a pose: back to your spot once every note is let go
    if Fly.returnHome and next(Fly.held) == nil and now - Fly.lastPose > Fly.poseTime then
        Fly.retOff = Fly.retOff * math.exp(-dt * 3 / math.max(Fly.returnTime, 0.05))
        if Fly.retOff.Magnitude < 0.01 then Fly.retOff = Fly.ZERO end
    end
    local goal = Fly.home + Fly.retOff + Air.off
    if Fly.hover then goal = goal + Vector3.new(0, math.sin(now * 2.2) * 0.3, 0) end

    -- the point you're steered to eases toward the goal: a pose move takes about poseTime
    local prev = Fly.pos
    if Fly.snapPending then
        -- a pose cut into the last one's move: you're there at once
        Fly.snapPending = false
        prev = Fly.snapTo(root, goal)
        Fly.home = Fly.home + (prev - goal)     -- a wall stopped you short: that's your spot now
        Fly.pos = prev
    else
        Fly.pos = prev + (goal - prev) * (1 - math.exp(-dt * 3 / math.max(Fly.poseTime, 0.03)))
    end
    local ff = (Fly.pos - prev) / dt

    -- stopped by a wall or the floor: don't let the spot run off inside it
    local err = Fly.pos - root.Position
    if err.Magnitude > 5 then
        local back = err - err.Unit * 5
        Fly.home, Fly.pos = Fly.home - back, Fly.pos - back
        err = Fly.pos - root.Position
    end
    local vel = err * 10 + ff
    if vel.Magnitude > 80 then vel = vel.Unit * 80 end
    lv.VectorVelocity = vel

    -- face the way the layout says, leaning into your moves
    Fly.rot = Fly.rot:Lerp(CFrame.lookAt(Fly.ZERO, face), 1 - math.exp(-10 * dt))
    local rot = Fly.rot
    local actual = root.AssemblyLinearVelocity
    if Fly.lean then
        local ownRight = face:Cross(Fly.UP)
        local want = Vector3.new(math.clamp(-actual:Dot(face) * 0.012, -0.35, 0.35), 0,
                                 math.clamp(-actual:Dot(ownRight) * 0.02, -0.4, 0.4))
        Fly.tilt = Fly.tilt:Lerp(want, 1 - math.exp(-8 * dt))
        rot = rot * CFrame.Angles(Fly.tilt.X, 0, Fly.tilt.Z)
    end
    if Air.tilt ~= 0 then rot = rot * CFrame.Angles(Air.tilt, 0, 0) end   -- thrown back by a hit, or KO'd
    root.CFrame = CFrame.new(root.Position) * rot
    root.AssemblyAngularVelocity = Fly.ZERO

    Fly.animStep(actual.Magnitude)
end

-- ============================================================
--  AIR COMBAT (FLY tab)
--  Hand-to-hand in the air with your FNF opponent, for RP. Nobody
--  takes real damage: both health bars are only on your screen.
--  Everyone sees your own character: your jabs (a dash at them and
--  back), the knockback, the KO and the fall, and the clash teleport.
--  The flashes and banners are only on your screen. If your opponent
--  runs this too, their script does the same for them.
--
--  Your notes are jabs. Their notes (every pose their character plays)
--  hit you. Hit the same arrow at the same moment as them and it's a
--  CLASH: nobody gets hurt, and you teleport somewhere else mid-air.
-- ============================================================
Air.ZERO = Vector3.new(0, 0, 0)
Air.DIRS = { "LEFT", "DOWN", "UP", "RIGHT" }
Air.WHITE  = Color3.fromRGB(245, 245, 255)
Air.PINK   = Color3.fromRGB(255, 80, 180)
Air.CYAN   = Color3.fromRGB(80, 200, 255)
Air.GOLD   = Color3.fromRGB(255, 220, 80)
Air.RED    = Color3.fromRGB(255, 70, 70)

function Air.foeRoot()
    local c = Air.foe and Air.foe.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

-- Seconds between them posing and it showing on your screen: half their
-- ping plus half yours (theirs is guessed to be yours if it can't be read).
function Air.lag()
    local now = os.clock()
    if now - Air.lagT < 1 then return Air.lagV end
    Air.lagT = now
    local mine
    local ok, v = pcall(function()
        return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    end)
    if ok and type(v) == "number" and v > 0 then mine = v end
    if not mine then
        local ok2, p = pcall(function() return LocalPlayer:GetNetworkPing() end)
        mine = (ok2 and type(p) == "number" and p > 0) and p or 0.1
    end
    local theirs = mine
    local ok3, p3 = pcall(function() return Air.foe:GetNetworkPing() end)
    if ok3 and type(p3) == "number" and p3 > 0 and p3 < 5 then theirs = p3 end
    Air.lagV = math.min((mine + theirs) / 2 + 1/60, 1)
    return Air.lagV
end

-- ---------- animations ----------

-- The ID you pasted, else your character's own animation from its Animate
-- script (Roblox's, so it plays in any game).
function Air.track(id, animateName, preferred)
    if not animator then return nil end
    if Air.tracksFor ~= animator then Air.tracks, Air.tracksFor = {}, animator end
    id = tostring(id or ""):match("%d+") or ""
    local key = (id ~= "") and id or ("@" .. animateName)
    if Air.tracks[key] then return Air.tracks[key] end
    local anim
    if id ~= "" then
        anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://" .. id
    else
        local animate = character and character:FindFirstChild("Animate")
        local folder = animate and animate:FindFirstChild(animateName)
        anim = folder and (folder:FindFirstChild(preferred) or folder:FindFirstChildOfClass("Animation"))
        if not (anim and anim:IsA("Animation")) then return nil end
    end
    local ok, tr = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not tr then return nil end
    -- above your poses (they're Action)
    if not pcall(function() tr.Priority = Enum.AnimationPriority.Action4 end) then
        tr.Priority = Enum.AnimationPriority.Action
    end
    Air.tracks[key] = tr
    return tr
end

function Air.stopAnims(fade)
    for _, t in pairs(Air.tracks) do
        pcall(function() if t.IsPlaying then t:Stop(fade or 0.2) end end)
    end
end

-- kind: HIT, KO or WIN
function Air.play(kind)
    local t
    if kind == "HIT" then t = Air.track(Air.hitAnim, "fall", "FallAnim")
    elseif kind == "KO" then t = Air.track(Air.koAnim, "fall", "FallAnim")
    else t = Air.track(Air.winAnim, "cheer", "CheerAnim") end
    if not t then return nil end
    Air.stopAnims(0.05)
    pcall(function()
        t.Looped = (kind == "KO")
        t:Play(0.05)
        t:AdjustSpeed(1)
    end)
    return t
end

-- KO pose: hold still on a frame. Your own KO animation holds its last
-- frame; the built-in one holds a moment in, arms flung up.
function Air.freeze(t, custom)
    task.spawn(function()
        local t0 = os.clock()
        while F.alive and t.IsPlaying and os.clock() - t0 < 4 do
            local len = t.Length
            local ready
            if custom then
                ready = len > 0 and t.TimePosition >= len - 0.08
            else
                ready = os.clock() - t0 >= 0.3
            end
            if ready then
                pcall(function()
                    t:AdjustSpeed(0)
                    if custom and len > 0 then t.TimePosition = len - 0.04 end
                end)
                return
            end
            RunService.Heartbeat:Wait()
        end
    end)
end

-- the jab for this arrow while fighting ("" = the arrow's own pose)
function Air.jabFor(dir)
    if not (Air.on and Air.state == "FIGHT" and not Air.ko) then return nil end
    local id = Air["jab" .. tostring(dir)]
    return type(id) == "string" and id:match("%d+") or nil
end

-- ---------- on your screen only ----------

function Air.flash(pos, col, size)
    local p = Instance.new("Part")
    p.Name = "FNFAirFlash"
    p.Shape = Enum.PartType.Ball
    p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
    p.Material = Enum.Material.Neon
    p.Color = col
    p.Transparency = 0.15
    p.Size = Vector3.new(1, 1, 1) * (size * 0.35)
    p.CFrame = CFrame.new(pos)
    p.Parent = Workspace
    TweenService:Create(p, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = Vector3.new(1, 1, 1) * size, Transparency = 1 }):Play()
    task.delay(0.35, function() pcall(function() p:Destroy() end) end)
end

function Air.dropHud()
    if Air.hud and Air.hud.gui then pcall(function() Air.hud.gui:Destroy() end) end
    Air.hud = nil
end

function Air.buildHud()
    Air.dropHud()
    local old = PlayerGui:FindFirstChild("FNFAirCombat")
    if old then old:Destroy() end
    local sg = F.own(Instance.new("ScreenGui"))
    sg.Name = "FNFAirCombat"; sg.IgnoreGuiInset = true
    sg.ResetOnSpawn = false; sg.DisplayOrder = F.silZ(136)
    sg.Parent = PlayerGui
    local h = { gui = sg }

    local top = Instance.new("Frame")
    top.Size = UDim2.new(0, 520, 0, 60)
    top.Position = UDim2.new(0.5, 0, 0, 60)
    top.AnchorPoint = Vector2.new(0.5, 0)
    top.BackgroundTransparency = 1
    top.Parent = sg

    local function text(parent, pos, size, str, ts, align)
        local l = Instance.new("TextLabel")
        l.Position, l.Size = pos, size
        l.BackgroundTransparency = 1
        l.Font = Enum.Font.GothamBold
        l.TextSize = ts
        l.TextColor3 = Air.WHITE
        l.TextStrokeTransparency = 0.35
        l.TextXAlignment = align or Enum.TextXAlignment.Center
        l.Text = str
        l.Parent = parent
        return l
    end
    local function bar(x, anchorX, col, name)
        local back = Instance.new("Frame")
        back.Size = UDim2.new(0, 220, 0, 16)
        back.Position = UDim2.new(0, x, 0, 22)
        back.BackgroundColor3 = Color3.fromRGB(20, 18, 28)
        back.BorderSizePixel = 0
        back.Parent = top
        F.uiCorner(back, UDim.new(0, 5))
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(1, 0, 1, 0)
        fill.AnchorPoint = Vector2.new(anchorX, 0)
        fill.Position = UDim2.new(anchorX, 0, 0, 0)
        fill.BackgroundColor3 = col
        fill.BorderSizePixel = 0
        fill.Parent = back
        F.uiCorner(fill, UDim.new(0, 5))
        local align = (anchorX == 0) and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
        text(top, UDim2.new(0, x, 0, 2), UDim2.new(0, 220, 0, 18), name, 13, align)
        local pips = text(top, UDim2.new(0, x, 0, 40), UDim2.new(0, 220, 0, 16), "", 13, align)
        return fill, pips
    end
    h.meFill, h.mePips = bar(0, 0, Air.PINK, "YOU")
    h.themFill, h.themPips = bar(300, 1, Air.CYAN, Air.foe and Air.foe.DisplayName or "THEM")
    h.round = text(top, UDim2.new(0, 220, 0, 18), UDim2.new(0, 80, 0, 24), "R1", 16)

    local banner = text(sg, UDim2.new(0.5, -350, 0.3, 0), UDim2.new(0, 700, 0, 90), "", 56)
    banner.Font = Enum.Font.GothamBlack
    banner.TextTransparency, banner.TextStrokeTransparency = 1, 1
    h.banner = banner

    Air.hud = h
    Air.hudUpdate()
end

function Air.hudUpdate()
    local h = Air.hud
    if not (h and h.gui and h.gui.Parent) then return end
    local ti = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(h.meFill, ti, { Size = UDim2.new(math.clamp(Air.hpMe, 0, 1), 0, 1, 0) }):Play()
    TweenService:Create(h.themFill, ti, { Size = UDim2.new(math.clamp(Air.hpThem, 0, 1), 0, 1, 0) }):Play()
    local need = math.ceil(Air.rounds / 2)
    local function pips(wins)
        local s = ""
        for i = 1, need do s = s .. ((i <= wins) and "● " or "○ ") end
        return s
    end
    h.mePips.Text = pips(Air.winsMe)
    h.themPips.Text = pips(Air.winsThem)
    h.round.Text = "R" .. Air.round
end

function Air.banner(str, col, secs)
    local h = Air.hud
    if not (h and h.banner and h.banner.Parent) then return end
    local b = h.banner
    Air.bannerN = Air.bannerN + 1
    local n = Air.bannerN
    b.Text = str
    b.TextColor3 = col or Air.WHITE
    b.TextTransparency, b.TextStrokeTransparency = 0, 0.2
    b.TextSize = 72
    TweenService:Create(b, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { TextSize = 56 }):Play()
    task.delay(secs or 1, function()
        if Air.bannerN ~= n or not b.Parent then return end
        TweenService:Create(b, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
    end)
end

-- ---------- their notes ----------

function Air.unbindFoe()
    for _, k in ipairs({ "foeConn", "foeCharConn" }) do
        if Air[k] then
            pcall(function() Air[k]:Disconnect() end)
            Air[k] = nil
        end
    end
end

function Air.bindFoe()
    Air.unbindFoe()
    local foe = Air.foe
    if not foe then return end
    local function bind(char)
        task.spawn(function()
            local hum = char and char:WaitForChild("Humanoid", 8)
            local anr = hum and (hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 5))
            if not anr or Air.foe ~= foe then return end
            if Air.foeConn then Air.foeConn:Disconnect() end
            Air.foeConn = F.own(anr.AnimationPlayed:Connect(function(tr)
                local ok, err = pcall(Air.onTheirPose, tr)
                if not ok then F.log("air combat: " .. tostring(err)) end
            end))
        end)
    end
    if foe.Character then bind(foe.Character) end
    Air.foeCharConn = F.own(foe.CharacterAdded:Connect(bind))
end

-- Not a note: their walk/fall/emotes (from their Animate script), and this
-- script's own hit, KO and win animations if they run it too (those play
-- above poses, at Action4). Otherwise your jab would make them "hit" you back.
function Air.notANote(track, id)
    if Copy.isMove(track) then return true end
    local ok, top = pcall(function() return track.Priority == Enum.AnimationPriority.Action4 end)
    if ok and top then return true end
    local animate = Air.foe and Air.foe.Character and Air.foe.Character:FindFirstChild("Animate")
    if animate then
        for _, a in ipairs(animate:GetDescendants()) do
            if a:IsA("Animation") and (a.AnimationId:match("%d+") or "") == id then return true end
        end
    end
    return false
end

-- which arrow that pose is: taught, else one of yours (same binds), else unknown
function Air.theirDir(id)
    if Air.taughtFor == Air.foe and Air.taught[id] then return Air.taught[id] end
    for _, dir in ipairs(Air.DIRS) do
        local row = F.rowForDir(dir)
        if row then
            if row.id == id then return dir end
            for _, a in ipairs(row.alts or {}) do
                if a.id == id then return dir end
            end
        end
        local s = cutterSlices[dir]
        if s and s.id == id then return dir end
    end
    return nil
end

-- an arrow it can't tell clashes on timing alone
function Air.sameNote(a, b)
    if not Air.sameArrow or a == nil or b == nil then return true end
    return a == b
end

function Air.startTeach()
    local foe = currentTarget
    if not foe then
        F.notify("Pick your FNF opponent first", "warn")
        return
    end
    if Air.taughtFor ~= foe then Air.taught, Air.taughtFor = {}, foe end
    Air.teach, Air.teachUsed = { "LEFT", "DOWN", "UP", "RIGHT" }, {}
    if not Air.on then
        Air.foe = foe
        Air.bindFoe()
    end
    F.notify("Ask " .. foe.DisplayName .. " to hit LEFT, DOWN, UP, RIGHT once each, in that order", "info")
    if Air.refreshUI then Air.refreshUI() end
end

function Air.onTheirPose(track)
    local id = Copy.idOf(track)
    if not id or Air.notANote(track, id) then return end

    -- TEACH: their next different poses are LEFT, DOWN, UP, RIGHT in turn
    if Air.teach and Air.taughtFor == Air.foe then
        if not Air.teachUsed[id] then
            Air.teachUsed[id] = true
            Air.taught[id] = table.remove(Air.teach, 1)
            if #Air.teach == 0 then
                Air.teach = nil
                F.notify("Learned all four of " .. Air.foe.DisplayName .. "'s arrows", "success")
                if not Air.on then Air.unbindFoe() end
            end
            if Air.refreshUI then Air.refreshUI() end
        end
        return     -- teaching poses don't hit you
    end

    if not Air.on or Air.state ~= "FIGHT" then return end
    local now = os.clock()
    local their = { t = now - Air.lag(), dir = Air.theirDir(id), done = false }

    -- your note on the same arrow at the same moment: CLASH
    for _, m in ipairs(Air.mine) do
        if not m.used and Air.sameNote(m.dir, their.dir) and math.abs(m.t - their.t) <= Air.clashWindow then
            m.used = true
            Air.hpThem = math.min(1, Air.hpThem + m.dmg)    -- your jab didn't land after all
            Air.clash()
            return
        end
    end

    table.insert(Air.theirs, their)
    while #Air.theirs > 0 and now - Air.theirs[1].t > 2 do table.remove(Air.theirs, 1) end
    -- wait out the clash window in case your matching note is still coming
    local gen = Air.gen
    task.delay(math.max(0, their.t + Air.clashWindow - now), function()
        if Air.gen ~= gen or their.done or Air.state ~= "FIGHT" then return end
        their.done = true
        Air.getHit()
    end)
end

-- ---------- your notes ----------

function Air.onPress(dir)
    if not Air.on or Air.state ~= "FIGHT" or Air.ko then return end
    local now = os.clock()
    -- their note on the same arrow at the same moment: CLASH
    for _, th in ipairs(Air.theirs) do
        if not th.done and Air.sameNote(dir, th.dir) and math.abs(now - th.t) <= Air.clashWindow then
            th.done = true
            Air.clash()
            return
        end
    end
    local dmg = math.min(Air.damage / 100, Air.hpThem)
    Air.hpThem = Air.hpThem - dmg
    table.insert(Air.mine, { t = now, dir = dir, dmg = dmg, used = false })
    while #Air.mine > 0 and now - Air.mine[1].t > 2 do table.remove(Air.mine, 1) end
    Air.jab(dir)
    Air.hudUpdate()
    if Air.hpThem <= 0.0001 then Air.roundOver(true) end
end

-- A jab: dash a few studs at them (40 studs a second at most), then back.
-- The arrow leans it a little: LEFT / RIGHT from that side, UP high, DOWN low.
function Air.jab(dir)
    local root, fr = Fly.root, Air.foeRoot()
    if not (root and fr) then return end
    local to = fr.Position - root.Position
    local dist = to.Magnitude
    if dist < 0.5 then return end
    local reach = math.min(Air.dashDist, math.max(dist - 3, 0))     -- stop short of them
    local _, right = Fly.frame()
    local side = Air.ZERO
    if dir == "LEFT" then side = -right
    elseif dir == "RIGHT" then side = right
    elseif dir == "UP" then side = Fly.UP
    elseif dir == "DOWN" then side = -Fly.UP end
    local vec = to.Unit * reach + side * 0.8
    local len = vec.Magnitude
    if len < 0.05 then return end
    Air.dash = {
        t0 = os.clock(), vec = vec,
        out = math.max(len / 40, 0.06),
        hold = 0.06,
        back = math.max(0.22, 1.5 * len / 40),
    }
end

-- ---------- getting hit ----------

function Air.getHit()
    if not Air.on or Air.state ~= "FIGHT" or Air.ko then return end
    Air.hpMe = math.max(0, Air.hpMe - Air.damage / 100)
    Air.knockback()
    Air.hudUpdate()
    if Air.hpMe <= 0.0001 then Air.roundOver(false) end
end

function Air.knockback()
    local root, fr = Fly.root, Air.foeRoot()
    Air.dash = nil
    if root and fr then
        local away = root.Position - fr.Position
        away = (away.Magnitude > 0.1) and away.Unit or -root.CFrame.LookVector
        away = (away + Vector3.new(0, 0.25, 0)).Unit
        -- the push fades at rate 6, so it carries you knock studs in all
        Air.kbVel = Air.kbVel + away * (Air.knock * 6)
        if Air.kbVel.Magnitude > 40 then Air.kbVel = Air.kbVel.Unit * 40 end
        Air.flash(root.Position - away * 1.2, Air.RED, 3)
    end
    Air.tiltKick = math.min(Air.tiltKick + 0.55, 0.9)
    local t = Air.play("HIT")
    if t then
        Air.hitN = Air.hitN + 1
        local n, gen = Air.hitN, Air.gen
        task.delay(0.45, function()
            if Air.hitN == n and Air.gen == gen and not Air.ko then
                pcall(function() t:Stop(0.2) end)
            end
        end)
    end
end

-- ---------- clash ----------

function Air.clash()
    local root, fr = Fly.root, Air.foeRoot()
    Air.dash = nil
    Air.banner("CLASH!", Air.GOLD, 0.7)
    pcall(function() FNFCamera:DoubleNoteZoom(1) end)
    if root and fr then
        Air.flash((root.Position + fr.Position) / 2, Color3.fromRGB(255, 240, 150), 7)
        local away = root.Position - fr.Position
        if away.Magnitude > 0.1 then Air.kbVel = away.Unit * 18 end    -- knocked apart a little
    end
    Air.tiltKick = 0.35
    Air.hudUpdate()
    local gen = Air.gen
    task.delay(0.22, function()
        if Air.gen ~= gen or not Air.on or Air.ko then return end
        Air.teleport()
    end)
end

-- Somewhere else around them mid-air, at most tpDist studs from where you
-- are. Stops 2 studs short of anything in the way, so never into a wall.
function Air.teleport()
    local root, fr = Fly.root, Air.foeRoot()
    if not (root and fr and Fly.home) then return end
    local from = root.Position
    local rel = from - fr.Position
    local flat = Vector3.new(rel.X, 0, rel.Z)
    local d = math.clamp(flat.Magnitude, 6, 14)
    flat = (flat.Magnitude > 0.1) and flat.Unit or Vector3.new(0, 0, 1)
    local turn = math.rad(math.random(60, 150)) * ((math.random() < 0.5) and -1 or 1)
    local around = CFrame.Angles(0, turn, 0) * flat
    local spot = fr.Position + around * d
    local goal = Vector3.new(spot.X, from.Y + math.random() * 5 - 1, spot.Z)
    local move = goal - from
    if move.Magnitude > Air.tpDist then
        goal = from + move.Unit * Air.tpDist
        move = goal - from
    end
    if move.Magnitude < 0.5 then return end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character, Air.foe.Character }
    pcall(function() params.RespectCanCollide = true end)
    local hit = Workspace:Raycast(from, move, params)
    if hit then goal = from + move.Unit * math.max(0, (hit.Position - from).Magnitude - 2) end

    Air.flash(from, Air.CYAN, 5)
    root.CFrame = CFrame.new(goal) * root.CFrame.Rotation
    root.AssemblyLinearVelocity = Air.ZERO
    Fly.home, Fly.pos = goal, goal
    Air.kbVel, Air.off = Air.ZERO, Air.ZERO
    Air.flash(goal, Air.CYAN, 5)
end

-- ---------- rounds ----------

function Air.setState(s)
    Air.state = s
    if Air.refreshUI then Air.refreshUI() end
end

function Air.newRound()
    Air.hpMe, Air.hpThem = 1, 1
    Air.ko, Air.dash, Air.drop = false, nil, nil
    Air.mine, Air.theirs = {}, {}
    Air.setState("INTRO")
    Air.hudUpdate()
    Air.banner("ROUND " .. Air.round, Air.WHITE, 0.9)
    local gen, round = Air.gen, Air.round
    task.delay(1.1, function()
        if Air.gen ~= gen or Air.state ~= "INTRO" or Air.round ~= round then return end
        Air.setState("FIGHT")
        Air.banner("FIGHT!", Air.PINK, 0.6)
    end)
end

function Air.roundOver(iWon)
    Air.setState("KO")
    Air.dash = nil
    if iWon then Air.winsMe = Air.winsMe + 1 else Air.winsThem = Air.winsThem + 1 end
    local need = math.ceil(Air.rounds / 2)
    local matchOver = Air.winsMe >= need or Air.winsThem >= need
    Air.hudUpdate()
    local gen = Air.gen

    if iWon then
        Air.banner("K.O.!", Air.GOLD, 1.2)
        local t = Air.play("WIN")
        task.delay(1.6, function()
            if Air.gen ~= gen then return end
            pcall(function() if t then t:Stop(0.3) end end)
            if matchOver then
                Air.finish(true)
            else
                Air.round = Air.round + 1
                Air.newRound()
            end
        end)
        return
    end

    -- you're knocked out: KO pose, hanging there mid-air
    Air.banner("K.O.", Air.RED, 1.2)
    Air.ko = true
    local t = Air.play("KO")
    if t then Air.freeze(t, (Air.koAnim or "") ~= "") end
    task.delay(Air.koHold, function()
        if Air.gen ~= gen then return end
        if matchOver then
            Air.finish(false)        -- then you fall
            return
        end
        -- not the last round: drop a few studs, catch yourself, go again
        Air.drop = os.clock() + 0.45
        task.delay(0.8, function()
            if Air.gen ~= gen then return end
            Air.drop, Air.ko = nil, false
            Air.stopAnims(0.25)
            Air.round = Air.round + 1
            Air.newRound()
        end)
    end)
end

function Air.finish(iWon)
    local name = Air.foe and Air.foe.DisplayName or "them"
    Air.banner(iWon and "YOU WIN" or "YOU LOSE", iWon and Air.GOLD or Air.RED, 2.2)
    local hud = Air.hud
    task.delay(2.6, function() if Air.hud == hud then Air.dropHud() end end)
    if iWon then
        Air.stop(nil, true)
        F.notify("You beat " .. name .. " in the air", "success")
    else
        Air.falling = true          -- keep the KO pose through the fall
        Air.stop(nil, true)
        Fly.stop(name .. " knocked you out", true)
    end
end

-- KNOCKED OUT: no fly force, so you fall lying back like a dead weight.
-- Once you've landed you lie there a moment, then get up.
function Air.limpFall(hum, root, savedAuto)
    if not (hum and hum.Parent and root and root.Parent and hum.Health > 0) then
        Air.falling = false
        return false
    end
    Air.falling = true
    local look = root.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    flat = (flat.Magnitude > 1e-3) and flat.Unit or Vector3.new(0, 0, -1)
    local lying = CFrame.lookAt(Air.ZERO, flat) * CFrame.Angles(1.35, 0, 0)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { root.Parent }
    task.spawn(function()
        local t0, landedAt = os.clock(), nil
        while F.alive and not Fly.enabled and hum.Parent and root.Parent and hum.Health > 0 do
            hum.PlatformStand = true
            local now = os.clock()
            if not landedAt then
                root.CFrame = CFrame.new(root.Position) * lying
                root.AssemblyAngularVelocity = Air.ZERO
                local hit = Workspace:Raycast(root.Position, Vector3.new(0, -4, 0), params)
                if (hit and root.AssemblyLinearVelocity.Y > -2) or now - t0 > 6 then landedAt = now end
            elseif now - landedAt > 1.2 then
                break
            end
            RunService.Heartbeat:Wait()
        end
        Air.falling = false
        Air.stopAnims(0.3)
        if Fly.enabled then
            Fly.savedAuto = savedAuto    -- flying again: landing later gives your turning back
            return
        end
        if not (hum.Parent and root.Parent) then return end
        pcall(function()
            hum.PlatformStand = false
            if savedAuto ~= nil then hum.AutoRotate = savedAuto end
            local p = root.Position + Vector3.new(0, 1.5, 0)
            root.CFrame = CFrame.lookAt(p, p + flat)
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
    end)
    return true
end

-- ---------- start / stop ----------

function Air.start()
    if Air.on then return end
    local foe = currentTarget
    if not foe or not foe.Parent then
        F.notify("Pick your FNF opponent first", "warn")
        return
    end
    if not Fly.enabled and not Fly.start() then return end
    if Air.taughtFor ~= foe then Air.taught, Air.taughtFor, Air.teach = {}, foe, nil end
    Air.foe = foe
    Air.gen = Air.gen + 1
    Air.on = true
    Air.round, Air.winsMe, Air.winsThem = 1, 0, 0
    Air.off, Air.kbVel, Air.tilt, Air.tiltKick = Air.ZERO, Air.ZERO, 0, 0
    Air.lagT = 0
    Air.bindFoe()
    Air.buildHud()
    Air.newRound()
    F.notify("Air combat with " .. foe.DisplayName .. " — your notes are jabs", "success")
end

function Air.stop(reason, keepHud)
    if not Air.on then return end
    Air.on = false
    Air.gen = Air.gen + 1
    Air.state = "OFF"
    Air.unbindFoe()
    Air.teach = nil
    Air.off, Air.kbVel, Air.dash, Air.drop = Air.ZERO, Air.ZERO, nil, nil
    Air.tilt, Air.tiltKick, Air.ko = 0, 0, false
    Air.mine, Air.theirs = {}, {}
    if not Air.falling then Air.stopAnims(0.2) end
    if not keepHud then Air.dropHud() end
    if Air.refreshUI then Air.refreshUI() end
    if reason then F.notify("Air combat over — " .. reason, "info") end
end

function Air.toggle()
    if Air.on then Air.stop("you stopped it") else Air.start() end
end

-- ---------- every frame, from Fly.step ----------

function Air.step(dt, now)
    if not (Air.foe and Air.foe.Parent) then
        Air.stop("your opponent left")
        return
    end
    if currentTarget ~= Air.foe then
        Air.stop("you picked a different opponent")
        return
    end
    -- knockback: a push that fades
    if Air.kbVel.Magnitude > 0.05 then
        Fly.home = Fly.home + Air.kbVel * dt
        Air.kbVel = Air.kbVel * math.exp(-6 * dt)
    else
        Air.kbVel = Air.ZERO
    end
    -- KO drop between rounds
    if Air.drop and now < Air.drop then
        Fly.home = Fly.home - Vector3.new(0, 14 * dt, 0)
    end

    local fr = Air.foeRoot()
    if fr and not Air.ko then
        local rel = Fly.home - fr.Position
        if Air.circle then
            rel = CFrame.Angles(0, math.rad(Air.circleSpeed) * dt, 0) * rel
            Fly.home = fr.Position + rel
        end
        local d = rel.Magnitude
        if Air.keepClose and d > Air.maxDist then
            Fly.home = Fly.home - rel.Unit * math.min(d - Air.maxDist, 20 * dt)
        elseif d < 4 and d > 0.01 then
            Fly.home = Fly.home + rel.Unit * math.min(4 - d, 10 * dt)    -- don't end up inside them
        end
    end

    -- the jab's dash out and back
    local dsh = Air.dash
    if dsh then
        local e = now - dsh.t0
        local f
        if e < dsh.out then
            f = e / dsh.out
        elseif e < dsh.out + dsh.hold then
            f = 1
        elseif e < dsh.out + dsh.hold + dsh.back then
            local a = (e - dsh.out - dsh.hold) / dsh.back
            f = 1 - a * a * (3 - 2 * a)
        else
            f = 0
            Air.dash = nil
        end
        Air.off = dsh.vec * f
    else
        Air.off = Air.ZERO
    end

    -- leaning back: a kick when you're hit, all the way back when you're KO'd
    Air.tiltKick = Air.tiltKick * math.exp(-5 * dt)
    local want = (Air.ko and 1.35 or 0) + Air.tiltKick
    Air.tilt = Air.tilt + (want - Air.tilt) * (1 - math.exp(-10 * dt))
end

-- ============================================================
--  POSE HOLD
--  When you let go of a short pose, it stays frozen on its final
--  frame for Hold.duration seconds instead of dropping back to
--  idle. Another real animation (Action priority and up, like an
--  emote or your next note) cuts the hold immediately. Idle,
--  Core and Movement tracks don't count, so standing around or
--  walking won't break it.
-- ============================================================
function Hold.qualifies(track)
    if not Hold.enabled or not track then return false end
    if track.Looped then return false end           -- hold-loop binds manage themselves
    if Hold.holdAll then return true end
    local len = track.Length
    return len > 0 and len <= Hold.shortAt
end

-- Drop our reference and kill any pending timer WITHOUT stopping the track.
-- Used when the same track is about to be reused, e.g. the cutter's one
-- shared track moving on to the next slice.
function Hold.detach()
    Hold.track = nil
    Hold.token = Hold.token + 1
end

function Hold.start(track, label)
    -- The cutter plays every slice on one shared track. Clearing a previous
    -- hold on that same track would stop the pose we're about to hold, which
    -- is what dropped you back to idle on every release after the first.
    if Hold.track and Hold.track ~= track then
        Hold.clear(false)
    else
        Hold.detach()
    end
    Hold.track = track
    Hold.label = label or "pose"
    Hold.token = Hold.token + 1
    Hold.releaseAt = os.clock() + Hold.duration
    if Hold.untilNext then return end        -- no timer: the next pose ends it
    local tok = Hold.token
    task.delay(Hold.duration, function()
        if Hold.token == tok then Hold.clear(true) end
    end)
end

-- natural = true when the timer ran out; false when something interrupted it
function Hold.clear(natural)
    local t = Hold.track
    Hold.track = nil
    Hold.token = Hold.token + 1
    if t and t.IsPlaying then
        pcall(function() t:Stop(natural and Hold.fadeOut or 0.05) end)
    end
    if natural then
        StatusState.playing = false
        if F.refreshStatusUI then F.refreshStatusUI() end
    end
    -- a held pose ending takes the arms down with it (unless a key is down)
    if next(Arms.down) == nil then Arms.relax() end
end

function Hold.remaining()
    if not Hold.track then return 0 end
    if Hold.untilNext then return math.huge end
    return math.max(0, Hold.releaseAt - os.clock())
end

-- Listen on the player's animator for anything that should break a hold.
function Hold.watch(animr)
    if Hold.conn then Hold.conn:Disconnect(); Hold.conn = nil end
    if not animr then return end
    Hold.conn = F.own(animr.AnimationPlayed:Connect(function(tr)
        if not Hold.track or tr == Hold.track or Arms.isMix(tr) then return end
        local p = tr.Priority
        if p == Enum.AnimationPriority.Idle
            or p == Enum.AnimationPriority.Core
            or p == Enum.AnimationPriority.Movement then
            return
        end
        Hold.clear(false)
    end))
end

-- ============================================================
--  HOLD TRAILS
--  Hold a note key and the game's hold-note trail comes out from
--  under that arrow, connected to it: the arrow plays its held
--  glow and the hold-cover sparks run on it (both from the strum
--  engine). Let go and the sparks burst off as the trail is
--  pulled back in. Taps never make a trail.
-- ============================================================
function Notes.strumY() return Arrows.size / 2 end
function Notes.laneX(dir)
    local f = arrowHudFrames[dir]
    return f and (f.slot + Arrows.size / 2) or 0
end

-- Trails live in the arrow strip, under the arrows, so each one comes out
-- from beneath its arrow and moves, leans and bobs with the strip. The
-- strip gets rebuilt sometimes, so re-home when it does.
function Notes.ensureLayer()
    local holder = Arrows.container
    if not holder or not holder.Parent then return nil end
    if Notes.layer and Notes.layer.Parent == holder then return Notes.layer end
    for _, h in pairs(Notes.held) do
        if h.tail then h.tail:Destroy() end
        h.tail, h.trail, h.active = nil, nil, false
    end
    local layer = Instance.new("Frame")
    layer.Name = "HoldTrails"
    layer.Size = UDim2.new(1, 0, 1, 0)
    layer.BackgroundTransparency = 1
    layer.ZIndex = F.silZ(62)        -- under the arrows (63)
    layer.Parent = holder
    Notes.layer = layer
    return layer
end

function Notes.press(dir)
    if not Notes.enabled then return end
    Notes.drop(dir)
    Notes.held[dir] = { start = os.clock(), active = false }
end

-- take a trail away without its ending (a fresh press on the same arrow)
function Notes.drop(dir)
    local h = Notes.held[dir]
    Notes.held[dir] = nil
    if h and h.tail then h.tail:Destroy() end
end

function Notes.release(dir)
    local h = Notes.held[dir]
    Notes.held[dir] = nil
    if not h or not h.active then return end
    -- the end of a hold note: the sparks burst off the arrow and the
    -- trail is pulled back in under it
    local f = arrowHudFrames[dir]
    if f then F.strumHoldEnd(f, dir, true) end
    local tail = h.tail
    if tail and tail.Parent then
        TweenService:Create(tail, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Size = UDim2.new(0, tail.Size.X.Offset, 0, 0) }):Play()
        task.delay(0.14, function() tail:Destroy() end)
    end
end

function Notes.step()
    if not Notes.enabled then return end
    local now = os.clock()
    local sign = (Notes.grow == "UP") and -1 or 1
    local layer = nil
    for dir, h in pairs(Notes.held) do
        local elapsed = now - h.start - Notes.startDelay
        local f = arrowHudFrames[dir]
        if elapsed > 0 and f then
            layer = layer or Notes.ensureLayer()
            if not layer then return end
            if not h.active then
                -- held long enough to be a hold note: trail out, glow and sparks on
                h.active = true
                h.trail = F.makeTrail(layer, dir, sign, Arrows.size, f.spr ~= nil)
                h.tail = h.trail.tail
                F.strumHoldStart(f, dir)
            end
            -- the trail is looks only; holding's health comes from Health.holdStep
            if h.tail and h.tail.Parent then
                local frac = math.clamp(elapsed / math.max(Notes.fullTime, 0.05), 0, 1)
                h.tail.Position = UDim2.new(0, Notes.laneX(dir), 0, Notes.strumY())
                F.sizeTrail(h.trail, Notes.length * frac)
            end
        end
    end
end

function Notes.clear()
    for dir, h in pairs(Notes.held) do
        if h.tail then h.tail:Destroy() end
        local f = arrowHudFrames[dir]
        if h.active and f then F.strumHoldEnd(f, dir, false) end
    end
    Notes.held = {}
end

function Notes.start()
    if Notes.conn then return end
    Notes.conn = F.own(RunService.RenderStepped:Connect(function() pcall(Notes.step) end))
end

function Notes.setEnabled(state)
    Notes.enabled = state
    if state then
        Notes.ensureLayer()
        Notes.start()
    else
        Notes.clear()
    end
    if Notes.refreshUI then Notes.refreshUI() end
    F.notify(state and "Hold trails ON" or "Hold trails OFF", "info")
end

-- ============================================================
--  LOADING SCREEN
--  Arrows pop in one by one, then the title slams in out of
--  nowhere. It checks for a saved setup and tells you whether
--  you're new or back. Click or press any key to skip.
-- ============================================================
function Intro.isNew()
    if Intro.seen then return false end
    -- same session re-inject with no file access: remember via getgenv
    local g
    pcall(function() g = getgenv().FNFInjectorTourSeen end)
    return not g
end

function Intro.markSeen()
    Intro.seen = true
    pcall(function() getgenv().FNFInjectorTourSeen = true end)
    if Save.available then pcall(function() Save.write(Save.slot, true) end) end
end

function Intro.startLoading()
    local old = PlayerGui:FindFirstChild("FNFLoading")
    if old then old:Destroy() end
    Intro.loadDone, Intro.skip = false, false

    local sg = F.own(Instance.new("ScreenGui"))
    sg.Name = "FNFLoading"
    sg.IgnoreGuiInset = true
    sg.ResetOnSpawn = false
    sg.DisplayOrder = F.silZ(195)
    sg.Parent = PlayerGui
    Intro.loadGui = sg

    local back = Instance.new("Frame")
    back.Size = UDim2.new(1, 0, 1, 0)
    back.BackgroundColor3 = Color3.fromRGB(6, 5, 12)
    back.BackgroundTransparency = 1
    back.BorderSizePixel = 0
    back.Active = true
    back.ZIndex = F.silZ(190)
    back.Parent = sg

    -- the arrows, centred, all hidden to start
    local arrows = {}
    local ARW, GAP = 78, 18
    local totalW = #ARROW_ORDER * ARW + (#ARROW_ORDER - 1) * GAP
    for i, dir in ipairs(ARROW_ORDER) do
        local a = Instance.new("Frame")
        a.AnchorPoint = Vector2.new(0.5, 0.5)
        a.Position = UDim2.new(0.5, -totalW / 2 + (i - 1) * (ARW + GAP) + ARW / 2, 0.5, 40)
        a.Size = UDim2.new(0, 0, 0, 0)
        a.Rotation = -25
        a.BackgroundColor3 = ARROW_COLORS[dir].hit
        a.BorderSizePixel = 0
        a.ZIndex = F.silZ(192)
        a.Parent = back
        F.uiCorner(a, UDim.new(0, 16))
        F.uiStroke(a, Color3.fromRGB(255, 255, 255), 2).Transparency = 0.3
        local s = Instance.new("TextLabel")
        s.Size = UDim2.new(1, 0, 1, 0)
        s.BackgroundTransparency = 1
        s.Text = ARROW_SYMBOLS[dir]
        s.TextColor3 = Color3.fromRGB(255, 255, 255)
        s.Font = Enum.Font.GothamBlack
        s.TextScaled = true
        s.ZIndex = F.silZ(193)
        s.Parent = a
        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0.2, 0); pad.PaddingBottom = UDim.new(0.2, 0)
        pad.Parent = s
        arrows[i] = a
    end

    -- the title, invisible until it slams in
    local title = Instance.new("TextLabel")
    title.AnchorPoint = Vector2.new(0.5, 0.5)
    title.Position = UDim2.new(0.5, 0, 0.5, -60)
    title.Size = UDim2.new(1, 0, 0, 80)
    title.BackgroundTransparency = 1
    title.Text = "FNF ANIM INJECTOR"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 120
    title.TextTransparency = 1
    title.TextStrokeColor3 = THEMES[currentThemeName].accent
    title.TextStrokeTransparency = 1
    title.ZIndex = F.silZ(193)
    title.Parent = back

    local flash = Instance.new("Frame")
    flash.Size = UDim2.new(1, 0, 1, 0)
    flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    flash.BackgroundTransparency = 1
    flash.BorderSizePixel = 0
    flash.ZIndex = F.silZ(194)
    flash.Parent = back

    local status = F.makeLabel(back, "", UDim2.new(0, 0, 0.5, 100), UDim2.new(1, 0, 0, 20),
        Color3.fromRGB(220, 220, 235), Enum.TextXAlignment.Center, 13)
    status.Font = Enum.Font.GothamMedium
    status.ZIndex = F.silZ(193)

    local barBg = Instance.new("Frame")
    barBg.AnchorPoint = Vector2.new(0.5, 0)
    barBg.Position = UDim2.new(0.5, 0, 0.5, 128)
    barBg.Size = UDim2.new(0, 260, 0, 4)
    barBg.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    barBg.BackgroundTransparency = 0.85
    barBg.BorderSizePixel = 0
    barBg.ZIndex = F.silZ(193)
    barBg.Parent = back
    F.uiCorner(barBg, UDim.new(1, 0))
    local barFill = Instance.new("Frame")
    barFill.Size = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = THEMES[currentThemeName].accent
    barFill.BorderSizePixel = 0
    barFill.ZIndex = F.silZ(194)
    barFill.Parent = barBg
    F.uiCorner(barFill, UDim.new(1, 0))

    local hint = F.makeLabel(back, "click or press any key to skip", UDim2.new(0, 0, 1, -40),
        UDim2.new(1, 0, 0, 16), Color3.fromRGB(150, 150, 170), Enum.TextXAlignment.Center, 10)
    hint.ZIndex = F.silZ(193)

    -- skip on click or any key
    local skipConns = {}
    local function doSkip() Intro.skip = true end
    table.insert(skipConns, back.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then doSkip() end
    end))
    table.insert(skipConns, F.own(UserInputService.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Keyboard then doSkip() end
    end)))

    -- a wait that ends early if you skip
    local function wait(sec)
        local t0 = os.clock()
        while os.clock() - t0 < sec do
            if Intro.skip then return end
            RunService.Heartbeat:Wait()
        end
    end

    task.spawn(function()
        -- backdrop in
        TweenService:Create(back, TweenInfo.new(0.25), { BackgroundTransparency = Intro.backdropOpacity }):Play()
        wait(0.2)

        -- arrows pop one after another
        for _, a in ipairs(arrows) do
            if Intro.skip then break end
            TweenService:Create(a, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, ARW, 0, ARW), Rotation = 0,
            }):Play()
            wait(0.11)
        end
        wait(0.35)

        -- title out of nowhere: no fade, it's just there, with a flash
        title.TextTransparency = Intro.titleOpacity
        title.TextStrokeTransparency = 0.4
        TweenService:Create(title, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { TextSize = 58 }):Play()
        flash.BackgroundTransparency = 0.55
        TweenService:Create(flash, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
        for _, a in ipairs(arrows) do
            TweenService:Create(a, TweenInfo.new(0.08), { Size = UDim2.new(0, ARW * 1.12, 0, ARW * 1.12) }):Play()
        end
        wait(0.1)
        for _, a in ipairs(arrows) do
            TweenService:Create(a, TweenInfo.new(0.2, Enum.EasingStyle.Back),
                { Size = UDim2.new(0, ARW, 0, ARW) }):Play()
        end

        -- scan for a saved setup
        status.Text = "scanning for your setup..."
        TweenService:Create(barFill, TweenInfo.new(math.max(0.2, Intro.duration - 1.6), Enum.EasingStyle.Quad),
            { Size = UDim2.new(1, 0, 1, 0) }):Play()
        wait(0.7)
        if Intro.isNew() then
            status.Text = "new here? quick tour coming up"
            status.TextColor3 = Color3.fromRGB(120, 230, 255)
        else
            status.Text = "welcome back — loading your setup"
            status.TextColor3 = Color3.fromRGB(120, 255, 150)
        end
        wait(math.max(0.3, Intro.duration - 1.9))

        -- out
        for _, c in ipairs(skipConns) do c:Disconnect() end
        local out = TweenInfo.new(0.35, Enum.EasingStyle.Quad)
        TweenService:Create(back, out, { BackgroundTransparency = 1 }):Play()
        for _, d in ipairs(back:GetDescendants()) do
            if d:IsA("TextLabel") then
                TweenService:Create(d, out, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
            elseif d:IsA("Frame") then
                TweenService:Create(d, out, { BackgroundTransparency = 1 }):Play()
            elseif d:IsA("UIStroke") then
                TweenService:Create(d, out, { Transparency = 1 }):Play()
            end
        end
        task.wait(0.38)
        sg:Destroy()
        Intro.loadDone = true
    end)
end

-- ============================================================
--  FIRST-TIME TOUR
--  Five cards, each switching the panel to the tab it explains
--  and pulsing that tab's button.
-- ============================================================
local TOUR = {
    {
        tab = "📋 BINDS", title = "1  ·  YOUR BINDS",
        body = "These are your four notes: Z X C V play LEFT, DOWN, UP and RIGHT. "
            .. "Click a key to change it, paste an animation ID into the box to set that note's pose, "
            .. "and hold TEST to preview. Start here — set up your four poses first.",
        chips = { "Z", "X", "C", "V" },
    },
    {
        tab = "🎥 CAM", title = "2  ·  THE CAMERA",
        body = "Turn on the cinematic camera, then type your opponent's name under SET OPPONENT "
            .. "and it frames the two of you. FIND A MATCH scans the server for other players "
            .. "who are running this script, so you can battle someone who has it too.",
    },
    {
        tab = "✂ CUTTER", title = "3  ·  EMOTE CUTTER",
        body = "Cuts one emote into four poses. Give each note an animation, scrub the timeline "
            .. "to the frame you want, and mark it. Switch CUTTER ON and your note keys play "
            .. "your cuts instead of the normal binds.",
    },
    {
        tab = "🎬 MAKER", title = "4  ·  EVERYTHING ELSE",
        body = "MAKER builds animation sequences and song sections. PREVIEW shows your character "
            .. "live. FAVES and LIST store animations you like. FX has the music player and visual "
            .. "extras. Press ` any time for a list of every keybind.",
    },
    {
        tab = "⚙ SETTINGS", title = "5  ·  SETTINGS",
        body = "Themes, the arrow HUD, save slots and autosave all live here. Your setup saves "
            .. "on its own, so it'll be waiting next time. You can replay this tour from here "
            .. "whenever you like.",
    },
}

function Intro.pulseTab(name)
    if Intro.pulse then Intro.pulse:Destroy(); Intro.pulse = nil end
    local btn = F.tabButtons and F.tabButtons[name]
    if not btn then return end
    local s = Instance.new("UIStroke")
    s.Name = "TourPulse"
    s.Color = Color3.fromRGB(255, 220, 90)
    s.Thickness = 2
    s.Parent = btn
    Intro.pulse = s
    task.spawn(function()
        while s.Parent do
            s.Transparency = 0.1 + 0.6 * math.abs(math.sin(os.clock() * 5))
            RunService.Heartbeat:Wait()
        end
    end)
end

function Intro.endTour()
    if Intro.pulse then Intro.pulse:Destroy(); Intro.pulse = nil end
    if Intro.tourGui then Intro.tourGui:Destroy(); Intro.tourGui = nil end
    if F.selectTab then F.selectTab("📋 BINDS") end
    Intro.markSeen()
end

function Intro.startTour()
    if Intro.tourGui then Intro.tourGui:Destroy() end
    Intro.step = 1

    local sg = F.own(Instance.new("ScreenGui"))
    sg.Name = "FNFTour"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = F.silZ(180)
    sg.Parent = PlayerGui
    Intro.tourGui = sg

    local card = Instance.new("Frame")
    card.Size = UDim2.new(0, 340, 0, 250)
    card.AnchorPoint = Vector2.new(1, 0)
    card.Position = UDim2.new(1, -12, 0, 12)
    local cardScale = Instance.new("UIScale")
    cardScale.Scale = Menu.current or 1
    cardScale.Parent = card
    card.BackgroundColor3 = Color3.fromRGB(16, 15, 24)
    card.BorderSizePixel = 0
    card.Active = true
    card.Draggable = true
    card.Parent = sg
    F.uiCorner(card, UDim.new(0, 14))
    F.uiStroke(card, Color3.fromRGB(255, 220, 90), 1.5).Transparency = 0.3

    local tag = F.makeLabel(card, "QUICK TOUR", UDim2.new(0, 16, 0, 12), UDim2.new(0, 160, 0, 14),
        Color3.fromRGB(255, 220, 90), Enum.TextXAlignment.Left, 10)
    tag.Font = Enum.Font.GothamBold
    local count = F.makeLabel(card, "", UDim2.new(1, -96, 0, 12), UDim2.new(0, 80, 0, 14),
        Color3.fromRGB(150, 150, 170), Enum.TextXAlignment.Right, 10)

    local title = F.makeLabel(card, "", UDim2.new(0, 16, 0, 30), UDim2.new(1, -32, 0, 24),
        Color3.fromRGB(255, 255, 255), Enum.TextXAlignment.Left, 16)
    title.Font = Enum.Font.GothamBlack

    local body = F.makeLabel(card, "", UDim2.new(0, 16, 0, 60), UDim2.new(1, -32, 0, 104),
        Color3.fromRGB(210, 210, 225), Enum.TextXAlignment.Left, 11)
    body.TextWrapped = true
    body.TextYAlignment = Enum.TextYAlignment.Top

    -- key chips, used on the binds card
    local chipRow = Instance.new("Frame")
    chipRow.Size = UDim2.new(1, -32, 0, 30)
    chipRow.Position = UDim2.new(0, 16, 0, 160)
    chipRow.BackgroundTransparency = 1
    chipRow.Parent = card
    local chipLayout = Instance.new("UIListLayout")
    chipLayout.FillDirection = Enum.FillDirection.Horizontal
    chipLayout.Padding = UDim.new(0, 8)
    chipLayout.Parent = chipRow

    -- progress dots
    local dots = {}
    for i = 1, #TOUR do
        local d = Instance.new("Frame")
        d.Size = UDim2.new(0, 8, 0, 8)
        d.Position = UDim2.new(0, 16 + (i - 1) * 14, 1, -46)
        d.BorderSizePixel = 0
        d.Parent = card
        F.uiCorner(d, UDim.new(1, 0))
        dots[i] = d
    end

    local skip = F.makeBtn(card, "SKIP", UDim2.new(0, 16, 1, -32), UDim2.new(0, 70, 0, 24),
        Color3.fromRGB(45, 40, 60), nil, 10)
    local back = F.makeBtn(card, "BACK", UDim2.new(1, -176, 1, -32), UDim2.new(0, 70, 0, 24),
        Color3.fromRGB(45, 40, 60), nil, 10)
    local nextB = F.makeBtn(card, "NEXT", UDim2.new(1, -100, 1, -32), UDim2.new(0, 84, 0, 24),
        Color3.fromRGB(255, 190, 60), Color3.fromRGB(20, 20, 25), 11)

    local function show()
        local s = TOUR[Intro.step]
        count.Text = Intro.step .. " / " .. #TOUR
        title.Text = s.title
        body.Text = s.body
        for _, c in ipairs(chipRow:GetChildren()) do
            if c:IsA("TextLabel") then c:Destroy() end
        end
        -- binds card: show the player's real keys, not just the defaults
        if s.chips then
            for i, row in ipairs(CurrentBindings) do
                local chip = Instance.new("TextLabel")
                chip.Size = UDim2.new(0, 56, 0, 28)
                chip.BackgroundColor3 = ARROW_COLORS[row.dir].hit
                chip.Text = row.key .. " " .. ARROW_SYMBOLS[row.dir]
                chip.TextColor3 = Color3.fromRGB(15, 15, 20)
                chip.Font = Enum.Font.GothamBlack
                chip.TextSize = 12
                chip.LayoutOrder = i
                chip.Parent = chipRow
                F.uiCorner(chip, UDim.new(0, 7))
            end
        end
        for i, d in ipairs(dots) do
            d.BackgroundColor3 = (i == Intro.step) and Color3.fromRGB(255, 220, 90) or Color3.fromRGB(60, 58, 75)
        end
        back.Visible = Intro.step > 1
        nextB.Text = (Intro.step == #TOUR) and "LET'S GO" or "NEXT"

        -- take them to the tab this card is about
        if F.selectTab then F.selectTab(s.tab) end
        Intro.pulseTab(s.tab)
        local main = PlayerGui:FindFirstChild("FNFInjectorGui")
        main = main and main:FindFirstChild("Main")
        if main then main.Visible = true end
        if F.setPanelOpen then F.setPanelOpen(true) end
    end

    nextB.MouseButton1Click:Connect(function()
        if Intro.step >= #TOUR then Intro.endTour() return end
        Intro.step = Intro.step + 1
        show()
    end)
    back.MouseButton1Click:Connect(function()
        Intro.step = math.max(1, Intro.step - 1)
        show()
    end)
    skip.MouseButton1Click:Connect(function() Intro.endTour() end)

    show()
end

-- Called at the end of launch: wait out the loading screen, show the
-- panel, then start the tour for new players.
function Intro.finishBoot()
    local gui = PlayerGui:FindFirstChild("FNFInjectorGui")
    local main = gui and gui:FindFirstChild("Main")
    if main then main.Visible = false end
    task.spawn(function()
        local deadline = os.clock() + 12
        while not Intro.loadDone and os.clock() < deadline do task.wait(0.05) end
        if main then
            main.Visible = true
            local target = main.Position
            main.Position = target + UDim2.new(0, 0, 0, 24)
            TweenService:Create(main, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                { Position = target }):Play()
        end
        if Intro.isNew() then
            task.wait(0.3)
            Intro.startTour()
        end
    end)
end

-- ============================================================
--  VIDEO PLAYER
--  Plays a video file from your own computer, locally. Roblox
--  can't accept files dragged in from Windows, so a folder in
--  your executor's workspace is the drop box: put a .webm in
--  there, refresh, click it. getcustomasset turns that file into
--  something Roblox can load on your client only, so nobody
--  else sees it.
-- ============================================================
function Vid.resolveApi()
    Vid.api = {
        asset      = findFn("getcustomasset", getcustomasset) or findFn("getsynasset", getsynasset),
        list       = findFn("listfiles", listfiles),
        isfile     = findFn("isfile", isfile),
        isfolder   = findFn("isfolder", isfolder),
        makefolder = findFn("makefolder", makefolder),
    }
    if Vid.api.makefolder then
        pcall(function()
            if not (Vid.api.isfolder and Vid.api.isfolder("FNFInjector")) then Vid.api.makefolder("FNFInjector") end
            if not (Vid.api.isfolder and Vid.api.isfolder(Vid.folder)) then Vid.api.makefolder(Vid.folder) end
        end)
    end
end

local function baseName(path)
    return (tostring(path):match("[^/\\]+$")) or tostring(path)
end

-- What's in the drop box? Returns { {path, name, ext}, ... }
function Vid.listFiles()
    local out = {}
    if not Vid.api.list then return out end
    local ok, files = pcall(Vid.api.list, Vid.folder)
    if not ok or type(files) ~= "table" then return out end
    for _, p in ipairs(files) do
        local name = baseName(p)
        local ext = (name:match("%.([%w]+)$") or ""):lower()
        if ext ~= "" then
            -- normalise to a path relative to the workspace folder
            table.insert(out, { path = Vid.folder .. "/" .. name, name = name, ext = ext })
        end
    end
    table.sort(out, function(a, b) return a.name:lower() < b.name:lower() end)
    return out
end

function Vid.buildPlayer()
    local old = PlayerGui:FindFirstChild("FNFVideo")
    if old then old:Destroy() end

    local sg = F.own(Instance.new("ScreenGui"))
    sg.Name = "FNFVideo"
    sg.IgnoreGuiInset = true
    sg.ResetOnSpawn = false
    sg.DisplayOrder = F.silZ(45)
    sg.Enabled = false
    sg.Parent = PlayerGui
    Vid.gui = sg

    local win = Instance.new("Frame")
    win.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    win.BorderSizePixel = 0
    win.Active = true
    win.Draggable = true
    win.ClipsDescendants = true
    win.Parent = sg
    F.uiCorner(win, UDim.new(0, 10))
    Vid.window = win

    local vf = Instance.new("VideoFrame")
    vf.Size = UDim2.new(1, 0, 1, 0)
    vf.BackgroundTransparency = 1
    vf.Looped = Vid.looped
    vf.Volume = Vid.volume
    vf.Parent = win
    Vid.frame = vf

    -- slim progress bar along the bottom of the window
    local barBg = Instance.new("Frame")
    barBg.AnchorPoint = Vector2.new(0, 1)
    barBg.Position = UDim2.new(0, 0, 1, 0)
    barBg.Size = UDim2.new(1, 0, 0, 3)
    barBg.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    barBg.BackgroundTransparency = 0.8
    barBg.BorderSizePixel = 0
    barBg.ZIndex = 3
    barBg.Parent = win
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 0, 1, 0)
    bar.BackgroundColor3 = THEMES[currentThemeName].accent
    bar.BorderSizePixel = 0
    bar.ZIndex = 4
    bar.Parent = barBg
    Vid.bar = bar

    local close = Instance.new("TextButton")
    close.Size = UDim2.new(0, 22, 0, 22)
    close.Position = UDim2.new(1, -28, 0, 6)
    close.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    close.BackgroundTransparency = 0.4
    close.Text = "X"
    close.TextColor3 = Color3.fromRGB(255, 255, 255)
    close.Font = Enum.Font.GothamBold
    close.TextSize = 11
    close.ZIndex = 5
    close.Parent = win
    F.uiCorner(close, UDim.new(1, 0))
    close.MouseButton1Click:Connect(function() Vid.stop() end)

    F.own(RunService.RenderStepped:Connect(function()
        if not Vid.frame or not Vid.gui.Enabled then return end
        local len = Vid.frame.TimeLength
        if len and len > 0 then
            Vid.bar.Size = UDim2.new(math.clamp(Vid.frame.TimePosition / len, 0, 1), 0, 1, 0)
            if Vid.timeLbl then
                Vid.timeLbl.Text = string.format("%d:%02d / %d:%02d",
                    math.floor(Vid.frame.TimePosition / 60), math.floor(Vid.frame.TimePosition % 60),
                    math.floor(len / 60), math.floor(len % 60))
            end
        end
    end))

    Vid.applyLayout()
end

-- Window, fullscreen, or a dim backdrop behind everything.
function Vid.applyLayout()
    local win = Vid.window
    if not win then return end
    -- The stage draws the characters one layer above the video. Any mode
    -- that lifts the video higher would cover them, so while the stage is
    -- on the video is pinned to the bottom, whatever mode is selected.
    local mode = Vid.stage.on and "BACKDROP" or Vid.display
    if mode == "FULLSCREEN" then
        win.AnchorPoint = Vector2.new(0, 0)
        win.Position = UDim2.new(0, 0, 0, 0)
        win.Size = UDim2.new(1, 0, 1, 0)
        win.Draggable = false
        Vid.gui.DisplayOrder = F.silZ(150)
    elseif mode == "BACKDROP" then
        win.AnchorPoint = Vector2.new(0, 0)
        win.Position = UDim2.new(0, 0, 0, 0)
        win.Size = UDim2.new(1, 0, 1, 0)
        win.Draggable = false
        Vid.gui.DisplayOrder = F.silZ(1)      -- underneath every other panel
    else
        win.AnchorPoint = Vector2.new(1, 1)
        win.Position = UDim2.new(1, -20, 1, -150)
        win.Size = UDim2.new(0, 480 * Vid.scale, 0, 270 * Vid.scale)
        win.Draggable = true
        Vid.gui.DisplayOrder = F.silZ(45)
    end
    win.BackgroundTransparency = Vid.stage.on and 0 or Vid.opacity
    if Vid.frame then Vid.frame.ImageTransparency = Vid.opacity end
    -- and the character layer always sits directly above the video
    if Vid.stage.gui then Vid.stage.gui.DisplayOrder = Vid.gui.DisplayOrder + 1 end
    if Vid.syncModes then Vid.syncModes() end
end

function Vid.setStatus(text, color)
    if Vid.statusLbl then
        Vid.statusLbl.Text = text
        Vid.statusLbl.TextColor3 = color or Color3.fromRGB(160, 160, 180)
    end
end

-- Load and play. `source` is a file path in the drop box, or a Roblox video ID.
function Vid.play(source, isAssetId)
    if not Vid.gui or not Vid.gui.Parent then Vid.buildPlayer() end
    local content
    if isAssetId then
        content = "rbxassetid://" .. source
    else
        if not Vid.api.asset then
            Vid.setStatus("Your executor has no getcustomasset, so local files can't load.", Color3.fromRGB(255, 120, 90))
            F.notify("Local videos need getcustomasset", "error")
            return
        end
        local ext = (tostring(source):match("%.([%w]+)$") or ""):lower()
        if ext ~= "webm" then
            Vid.setStatus("That's a ." .. ext .. " file. Roblox only plays .webm — convert it first.",
                Color3.fromRGB(255, 170, 80))
            F.notify("Convert to .webm first", "warn")
            return
        end
        local ok, res = pcall(Vid.api.asset, source)
        if not ok or not res then
            Vid.setStatus("getcustomasset failed: " .. tostring(res), Color3.fromRGB(255, 120, 90))
            return
        end
        content = res
        Vid.lastFile = source
    end

    local vf = Vid.frame
    pcall(function() vf:Pause() end)
    vf.Video = content
    vf.Looped = Vid.looped
    vf.Volume = Vid.volume
    Vid.current = source
    Vid.gui.Enabled = true
    Vid.applyLayout()
    Vid.setStatus("loading " .. baseName(source) .. "...", Color3.fromRGB(0, 200, 255))

    -- give it a few seconds to load before calling it a failure
    task.spawn(function()
        local deadline = os.clock() + 6
        while os.clock() < deadline and vf.Video == content and not vf.IsLoaded do task.wait(0.1) end
        if vf.Video ~= content then return end
        if vf.IsLoaded then
            pcall(function() vf:Play() end)
            Vid.setStatus("playing " .. baseName(source), Color3.fromRGB(120, 230, 150))
        else
            Vid.setStatus("Roblox couldn't load it. Try re-exporting as VP9 .webm, or a shorter clip.",
                Color3.fromRGB(255, 120, 90))
        end
    end)
end

function Vid.togglePause()
    local vf = Vid.frame
    if not vf or not Vid.current then return end
    if vf.Playing then pcall(function() vf:Pause() end) else pcall(function() vf:Play() end) end
end

function Vid.restart()
    local vf = Vid.frame
    if not vf or not Vid.current then return end
    vf.TimePosition = 0
    pcall(function() vf:Play() end)
end

function Vid.stop()
    if Vid.frame then pcall(function() Vid.frame:Pause() end) end
    if Vid.gui and not Vid.stage.on then Vid.gui.Enabled = false end
    if Vid.stage.on and Vid.frame then Vid.frame.Video = "" end   -- stage stays, background goes black
    Vid.current = nil
    Vid.setStatus("stopped")
end

-- ============================================================
--  BLACK SCREEN FADE
--  Smooth to black, a beat of darkness, then a slow fade back.
--  Pressing it again mid-fade drops you straight back to black.
-- ============================================================
function Vid.blackout()
    if not Vid.boGui or not Vid.boGui.Parent then
        local sg = F.own(Instance.new("ScreenGui"))
        sg.Name = "FNFBlackout"
        sg.IgnoreGuiInset = true
        sg.ResetOnSpawn = false
        sg.DisplayOrder = F.silZ(185)
        sg.Parent = PlayerGui
        local f = Instance.new("Frame")
        f.Name = "Black"
        f.Size = UDim2.new(1, 0, 1, 0)
        f.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        f.BackgroundTransparency = 1
        f.BorderSizePixel = 0
        f.Parent = sg
        Vid.boGui = sg
    end
    local f = Vid.boGui.Black
    Vid.boToken = Vid.boToken + 1
    local tok = Vid.boToken

    TweenService:Create(f, TweenInfo.new(math.max(Vid.boFadeIn, 0.01), Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
        { BackgroundTransparency = 0 }):Play()
    task.delay(Vid.boFadeIn + Vid.boHold, function()
        if Vid.boToken ~= tok then return end
        TweenService:Create(f, TweenInfo.new(math.max(Vid.boFadeOut, 0.05), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            { BackgroundTransparency = 1 }):Play()
    end)
end

-- ============================================================
--  VIDEO STAGE
--  The video plays full screen and hides the whole world. You
--  and your opponent are redrawn on top of it: exact copies in
--  a full-screen viewport, using your real camera, with every
--  body part copying its real position every frame. Normal
--  colours, no black fill. Nobody else is drawn at all.
-- ============================================================
local function relPath(inst, root)
    local parts = {}
    local cur = inst
    while cur and cur ~= root do
        table.insert(parts, 1, cur.Name)
        cur = cur.Parent
    end
    return table.concat(parts, "/")
end

local function countParts(char)
    local n = 0
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") then n = n + 1 end
    end
    return n
end

-- A still copy of a character whose parts get placed by hand every frame.
function Vid.stageClone(char)
    if not char or not char.Parent or not Vid.stage.vp then return nil end
    local was = char.Archivable
    char.Archivable = true
    local ok, clone = pcall(function() return char:Clone() end)
    char.Archivable = was
    if not ok or not clone then return nil end

    -- Joints would drag whole limbs around when we set one part's CFrame,
    -- so every part is freed and positioned on its own instead.
    local strip = {}
    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("LuaSourceContainer") or d:IsA("JointInstance") or d:IsA("WeldConstraint")
            or d:IsA("Constraint") or d:IsA("Sound") then
            table.insert(strip, d)
        end
    end
    for _, d in ipairs(strip) do d:Destroy() end

    local hum = clone:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function() hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end)
        pcall(function() hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff end)
        pcall(function() hum.RequiresNeck = false end)
        pcall(function() hum.BreakJointsOnDeath = false end)
    end

    -- pair every clone part with the real part at the same place in the tree
    local real = {}
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then real[relPath(p, char)] = p end
    end
    local map = {}
    for _, p in ipairs(clone:GetDescendants()) do
        if p:IsA("BasePart") then
            p.Anchored = true
            p.CanCollide = false
            local r = real[relPath(p, clone)]
            if r then table.insert(map, { r, p }) end
        end
    end

    clone.Name = "StageCopy"
    clone.Parent = Vid.stage.vp
    return { char = char, clone = clone, map = map, count = countParts(char) }
end

function Vid.stageDrop(entry)
    if entry and entry.clone then pcall(function() entry.clone:Destroy() end) end
end

-- Keep the copies pointed at the right characters: respawns, a new
-- opponent, or an outfit change all trigger a fresh copy.
function Vid.stageRefresh()
    local st = Vid.stage
    local wantMe = character
    local wantOpp = currentTarget and currentTarget.Character or nil

    for _, key in ipairs({ "me", "opp" }) do
        local want = (key == "me") and wantMe or wantOpp
        local e = st[key]
        local stale = e and (e.char ~= want or not e.char.Parent
            or countParts(e.char) ~= e.count or #e.map == 0)
        if stale or (not e and want) then
            Vid.stageDrop(e)
            st[key] = want and Vid.stageClone(want) or nil
        end
    end
end

function Vid.stageStep()
    local st = Vid.stage
    if not st.on or not st.vp then return end

    -- same camera as the real one, so the copies line up exactly
    local cam = Workspace.CurrentCamera
    if cam and st.cam then
        st.cam.CFrame = cam.CFrame
        st.cam.FieldOfView = cam.FieldOfView
    end

    for _, key in ipairs({ "me", "opp" }) do
        local e = st[key]
        if e then
            for _, pair in ipairs(e.map) do
                local r, c = pair[1], pair[2]
                if r.Parent then
                    c.CFrame = r.CFrame
                end
            end
        end
    end
end

function Vid.startStage()
    local st = Vid.stage
    if st.on then return end
    st.on = true
    st.prevDisplay = Vid.display

    -- the video layer: full screen, behind the panels
    if not Vid.gui or not Vid.gui.Parent then Vid.buildPlayer() end
    Vid.display = "BACKDROP"
    Vid.gui.Enabled = true
    Vid.applyLayout()
    if Vid.window then Vid.window.BackgroundTransparency = 0 end   -- solid black if nothing's playing
    if not Vid.current then F.notify("Stage on — play a video from the list for the background", "info") end

    -- the character layer, one step above the video
    local old = PlayerGui:FindFirstChild("FNFVideoStage")
    if old then old:Destroy() end
    local sg = F.own(Instance.new("ScreenGui"))
    sg.Name = "FNFVideoStage"
    sg.IgnoreGuiInset = true          -- must match the real camera's full screen
    sg.ResetOnSpawn = false
    sg.DisplayOrder = (Vid.gui and Vid.gui.DisplayOrder or 1) + 1
    sg.Parent = PlayerGui
    st.gui = sg

    local vp = Instance.new("ViewportFrame")
    vp.Size = UDim2.new(1, 0, 1, 0)
    vp.BackgroundTransparency = 1
    vp.Ambient = Color3.fromRGB(150, 150, 160)
    vp.LightColor = Color3.fromRGB(255, 255, 255)
    local okSun, sun = pcall(function() return game:GetService("Lighting"):GetSunDirection() end)
    vp.LightDirection = okSun and -sun or Vector3.new(-0.5, -1, -0.4)
    vp.Parent = sg
    st.vp = vp

    local cam = Instance.new("Camera")
    cam.Parent = vp
    vp.CurrentCamera = cam
    st.cam = cam

    Vid.stageRefresh()
    Vid.applyLayout()

    -- run right after the camera finishes, so nothing lags a frame
    pcall(function() RunService:UnbindFromRenderStep("FNFVideoStage") end)
    RunService:BindToRenderStep("FNFVideoStage", Enum.RenderPriority.Camera.Value + 1, Vid.stageStep)

    st.watch = task.spawn(function()
        while st.on do
            task.wait(0.5)
            if st.on then
                pcall(Vid.stageRefresh)
                -- real fades only (like the invisible root part), never the
                -- camera's zoomed-in hiding, which would erase your own copy
                for _, key in ipairs({ "me", "opp" }) do
                    local e = st[key]
                    if e then
                        for _, pair in ipairs(e.map) do
                            if pair[1].Parent then pair[2].Transparency = pair[1].Transparency end
                        end
                    end
                end
                if Vid.refreshStageUI then Vid.refreshStageUI() end
            end
        end
    end)

    if Vid.refreshStageUI then Vid.refreshStageUI() end
    if not currentTarget then F.notify("No opponent set — only you are shown. Pick one in the CAM tab.", "warn") end
end

function Vid.stopStage()
    local st = Vid.stage
    if not st.on then return end
    st.on = false
    pcall(function() RunService:UnbindFromRenderStep("FNFVideoStage") end)
    Vid.stageDrop(st.me); Vid.stageDrop(st.opp)
    st.me, st.opp = nil, nil
    if st.gui then st.gui:Destroy() end
    st.gui, st.vp, st.cam = nil, nil, nil

    Vid.display = st.prevDisplay or "WINDOW"
    if Vid.window then Vid.window.BackgroundTransparency = Vid.opacity end
    if not Vid.current and Vid.gui then Vid.gui.Enabled = false end
    Vid.applyLayout()
    if Vid.refreshStageUI then Vid.refreshStageUI() end
end

-- ============================================================
--  RESULT — win / lose
--  WIN plays a cheer. LOSE sits you down and launches you. Both
--  are manual: you decide the outcome with a key or a button.
-- ============================================================
function Result.mph(studsPerSec)
    return studsPerSec * 0.28 * 2.23694   -- ~0.28 m per stud
end

-- Your avatar's own built-in animation (cheer, sit...), which plays
-- in any game because Roblox owns it.
function Result.defaultAnim(slot)
    local animate = character and character:FindFirstChild("Animate")
    local folder = animate and animate:FindFirstChild(slot)
    local anim = folder and folder:FindFirstChildOfClass("Animation")
    return anim and anim.AnimationId or nil
end

function Result.loadTrack(customId, slot)
    if not animator then return nil end
    local id
    if customId and customId ~= "" then
        id = "rbxassetid://" .. customId
    else
        id = Result.defaultAnim(slot)
    end
    if not id then return nil end
    local ok, t = pcall(function()
        local a = Instance.new("Animation")
        a.AnimationId = id
        return animator:LoadAnimation(a)
    end)
    if ok and t then
        t.Priority = Enum.AnimationPriority.Action4   -- over every pose and emote
        return t
    end
    return nil
end

-- anything of ours currently posing you gets out of the way
function Result.clearPoses()
    if Hold.track then Hold.clear(false) end
    for _, t in pairs(animTracks) do pcall(function() t:Stop(0.1) end) end
    if cutterTrack and cutterTrack.IsPlaying then pcall(function() cutterTrack:Stop(0.1) end) end
end

function Result.showBanner(text, color)
    if not Result.banner then return end
    if not Result.gui or not Result.gui.Parent then
        local sg = F.own(Instance.new("ScreenGui"))
        sg.Name = "FNFResult"
        sg.IgnoreGuiInset = true
        sg.ResetOnSpawn = false
        sg.DisplayOrder = F.silZ(170)
        sg.Parent = PlayerGui
        local l = Instance.new("TextLabel")
        l.AnchorPoint = Vector2.new(0.5, 0.5)
        l.Position = UDim2.new(0.5, 0, 0.32, 0)
        l.Size = UDim2.new(1, 0, 0, 90)
        l.BackgroundTransparency = 1
        l.Font = Enum.Font.GothamBlack
        l.TextSize = 72
        l.TextStrokeTransparency = 0.2
        l.TextTransparency = 1
        l.Parent = sg
        Result.gui, Result.bannerLbl = sg, l
    end
    local l = Result.bannerLbl
    l.Text = text
    l.TextColor3 = color
    l.TextTransparency = 0
    l.TextStrokeTransparency = 0.2
    l.TextSize = 120
    l.Rotation = math.random(-6, 6)
    TweenService:Create(l, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { TextSize = 72, Rotation = 0 }):Play()
    task.delay(2, function()
        if l.Text == text then
            TweenService:Create(l, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
        end
    end)
end

function Result.win()
    if not character or not animator then return end
    Result.token = Result.token + 1
    local tok = Result.token
    Result.clearPoses()
    if Result.winTrack then pcall(function() Result.winTrack:Stop(0.1) end) end

    local t = Result.loadTrack(Result.cheerId, "cheer")
    if not t then
        F.notify("No cheer found — paste a cheer animation ID in the RESULT tab", "warn")
    else
        t.Looped = Result.cheerLoop
        t:Play(0.1)
        Result.winTrack = t
        if Result.cheerLoop then
            task.delay(Result.cheerTime, function()
                if Result.token == tok and t.IsPlaying then t:Stop(0.3) end
            end)
        end
    end

    Result.showBanner("YOU WIN!", Color3.fromRGB(255, 215, 70))
    if Cam2.outroOnResult then Cam2.play("OUTRO") end
    FNFCamera:DoubleNoteZoom(0.8)
    if Chaos.enabled then Chaos.hit(1.2) end
end

function Result.lose()
    local char = character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then return end
    Result.token = Result.token + 1
    local tok = Result.token
    Result.clearPoses()

    -- anything of ours that pins your body has to let go first
    if Ride.enabled then Ride.unlock("lost the battle") end
    if Fly.enabled then Fly.stop("lost the battle") end
    root.Anchored = false

    -- sitting pose
    if Result.sitTrack then pcall(function() Result.sitTrack:Stop(0) end) end
    local sit = Result.loadTrack(Result.sitId, "sit")
    if sit then
        sit.Looped = true
        sit:Play(0.05)
        Result.sitTrack = sit
    end

    -- hand the body to physics so the humanoid doesn't cancel the launch
    hum.PlatformStand = true

    -- which way you go flying
    local dir
    local oppRoot = currentTarget and currentTarget.Character
        and currentTarget.Character:FindFirstChild("HumanoidRootPart")
    if Result.direction == "AWAY" and oppRoot then
        dir = root.Position - oppRoot.Position
    elseif Result.direction == "RANDOM" then
        local a = math.random() * math.pi * 2
        dir = Vector3.new(math.cos(a), 0, math.sin(a))
    else
        dir = -root.CFrame.LookVector
    end
    dir = Vector3.new(dir.X, 0, dir.Z)
    dir = (dir.Magnitude > 1e-3) and dir.Unit or -root.CFrame.LookVector

    local vel = dir * Result.flingSpeed + Vector3.new(0, Result.lift, 0)
    root.AssemblyLinearVelocity = vel
    local axis = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
    if axis.Magnitude < 1e-3 then axis = Vector3.new(1, 0, 0) end
    root.AssemblyAngularVelocity = axis.Unit * Result.spin

    -- keep pushing for a split second so ground friction can't eat the launch
    local att = F.own(Instance.new("Attachment"))
    att.Parent = root
    local lv = F.own(Instance.new("LinearVelocity"))
    lv.Attachment0 = att
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.VectorVelocity = vel
    lv.MaxForce = math.huge
    lv.Parent = root
    task.delay(0.12, function() lv:Destroy(); att:Destroy() end)

    Result.showBanner("YOU LOSE", Color3.fromRGB(255, 70, 70))
    if Cam2.outroOnResult then Cam2.play("OUTRO") end
    if Chaos.enabled then Chaos.bigImpact(1.2) end

    -- recover
    task.delay(Result.getUpAfter, function()
        if Result.token ~= tok then return end
        if sit then pcall(function() sit:Stop(0.25) end) end
        if hum.Parent and hum.Health > 0 then
            hum.PlatformStand = false
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        end
    end)
end

-- ============================================================
--  NOTE PRESS / RELEASE
--  One path for every input: keyboard, touch arrows, anything
--  later. So every feature behaves the same however you play.
-- ============================================================
function F.notePress(row)
    Chars.sing(row.dir)
    local jabId = Air.jabFor(row.dir)     -- AIR COMBAT: this arrow's jab, if you set one
    if not jabId and cutterEnabled and (F.cutterSliceId(row.dir) or "") ~= "" then
        F.cutterPlaySlice(row.dir)
    else
        if Hold.track then Hold.clear(false) end
        for _, track in pairs(animTracks) do
            if track.IsPlaying then track:Stop(0) end
        end
        if jabId then
            F.playAnim(row.key, jabId, 1, false)
        else
            local chosenId = F.rollBindingAnimId(row)
            F.playAnim(row.key, chosenId, row.speedMult, row.holdLoop)
        end
    end
    -- the arms go out with the pose, further the faster you're posing
    Arms.onPress(row.dir)

    F.hitArrow(row.dir)
    FNFCamera:RegisterHit("PLAYER")
    -- Ask the game server to heal; the server must validate and rate-limit this.
    local poseHealRemote = ReplicatedStorage:FindFirstChild("PoseHealRequest")
    if poseHealRemote and poseHealRemote:IsA("RemoteEvent") then
        poseHealRemote:FireServer()
    end
    FNFCamera:RegisterDirectionalHit(row.dir)
    F.fightPlayerHit(row.dir)
    Ghost.tryPerfect(row.dir)
    F.swapFace(row.dir)
    if Fly.enabled then
        if Air.on then Air.onPress(row.dir) else Fly.onPose(row.dir) end
    else
        F.triggerRPMovement()
        if spacing then spacing:OnSingStart(character) end
    end
    Notes.press(row.dir)
    Health.holdBegin(row.dir)
    F.registerBpmTap()
    if F.refreshBpmDetectorUI then F.refreshBpmDetectorUI() end
end

function F.noteRelease(row)
    Chars.release(row.dir)
    if cutterEnabled then
        F.cutterStopSlice()
    else
        F.stopAnim(row.key)
    end
    F.releaseArrow(row.dir)
    F.restoreFace()
    if spacing then spacing:OnSingStop(character) end
    Notes.release(row.dir)
    Health.holdEnd(row.dir)
    Fly.onRelease(row.dir)
    Arms.onRelease(row.dir)   -- after the pose decides whether it's being held
end

function F.rowForDir(dir)
    for _, row in ipairs(CurrentBindings) do
        if row.dir == dir then return row end
    end
    return nil
end

-- ============================================================
--  MOBILE TOUCH ARROWS
--  FNF's mobile layout: two pairs along the bottom, ← ↓ on the
--  left and ↑ → on the right, with a gap in the middle for the
--  stage. Grey when idle, the note's colour when pressed. Every
--  finger is tracked on its own, so chords and holds work.
-- ============================================================
function Mobile.shouldShow()
    if Mobile.mode == "ON" then return true end
    if Mobile.mode == "OFF" then return false end
    return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function Mobile.layout()
    if not Mobile.gui then return end
    local cam = Workspace.CurrentCamera
    local vs = cam and cam.ViewportSize or Vector2.new(1280, 720)
    local W, H = vs.X, vs.Y

    local s = math.clamp(math.min(W * 0.1, H * 0.2), 58, 150) * Mobile.size
    local step = s + Mobile.pairGap
    local cx = W / 2
    local inner = W * Mobile.spread / 2
    local xs
    if Mobile.layoutMode == "LEFT" then
        -- all four under your left thumb
        local m = 24 + s / 2
        xs = { LEFT = m, DOWN = m + step, UP = m + step * 2, RIGHT = m + step * 3 }
    elseif Mobile.layoutMode == "RIGHT" then
        local m = W - 24 - s / 2
        xs = { LEFT = m - step * 3, DOWN = m - step * 2, UP = m - step, RIGHT = m }
    else
        xs = {
            LEFT  = cx - inner - step,
            DOWN  = cx - inner,
            UP    = cx + inner,
            RIGHT = cx + inner + step,
        }
    end
    for dir, b in pairs(Mobile.btns) do
        b.base = s
        b.frame.Size = UDim2.new(0, s, 0, s)
        b.frame.Position = UDim2.new(0, xs[dir], 1, -Mobile.bottom - s / 2)
        b.glyph.TextSize = math.floor(s * 0.42)
        local c = b.frame:FindFirstChildOfClass("UICorner")
        if c then c.CornerRadius = UDim.new(0, math.floor(s * 0.22)) end
    end
end

-- The same look and hit flash as the PC arrow strip, scaled up for thumbs.
function Mobile.paint(dir, down)
    local b = Mobile.btns[dir]
    if not b then return end
    local s = b.base or 80
    local colors = ARROW_COLORS[dir]
    if down then
        TweenService:Create(b.frame, TweenInfo.new(0.05, Enum.EasingStyle.Linear), {
            BackgroundColor3 = colors.hit,
            Size = UDim2.new(0, s * 1.16, 0, s * 1.16),
        }):Play()
        TweenService:Create(b.stroke, TweenInfo.new(0.05, Enum.EasingStyle.Linear), { Thickness = 4 }):Play()
        b.glow.Visible = true
        TweenService:Create(b.glow, TweenInfo.new(0.05), { BackgroundTransparency = 0.35 }):Play()
    else
        TweenService:Create(b.frame, TweenInfo.new(0.1, Enum.EasingStyle.Linear), {
            BackgroundColor3 = colors.idle,
            Size = UDim2.new(0, s, 0, s),
        }):Play()
        TweenService:Create(b.stroke, TweenInfo.new(0.1, Enum.EasingStyle.Linear), { Thickness = 2 }):Play()
        local tw = TweenService:Create(b.glow, TweenInfo.new(0.15), { BackgroundTransparency = 1 })
        tw:Play()
        tw.Completed:Connect(function()
            if (Mobile.held[dir] or 0) == 0 then b.glow.Visible = false end
        end)
    end
    -- idle see-through applies to the resting arrow only
    b.frame.BackgroundTransparency = down and 0.1 or math.clamp(0.3 + Mobile.idleFade, 0, 0.95)
    b.glyph.TextTransparency = down and 0 or math.clamp(Mobile.idleFade, 0, 0.9)
end

function Mobile.press(dir)
    Mobile.held[dir] = (Mobile.held[dir] or 0) + 1
    if Mobile.held[dir] > 1 then return end        -- a second finger on the same arrow
    Mobile.paint(dir, true)
    Mobile.buzz()
    local row = F.rowForDir(dir)
    if row then F.notePress(row) end
end

function Mobile.release(dir)
    Mobile.held[dir] = math.max(0, (Mobile.held[dir] or 0) - 1)
    if Mobile.held[dir] > 0 then return end        -- another finger is still on it
    Mobile.paint(dir, false)
    local row = F.rowForDir(dir)
    if row then F.noteRelease(row) end
end

function Mobile.build()
    local old = PlayerGui:FindFirstChild("FNFMobileNotes")
    if old then old:Destroy() end
    Mobile.btns, Mobile.touches, Mobile.held = {}, {}, {}

    local sg = F.own(Instance.new("ScreenGui"))
    sg.Name = "FNFMobileNotes"
    sg.IgnoreGuiInset = true
    sg.ResetOnSpawn = false
    sg.DisplayOrder = F.silZ(90)        -- under the main panel, over the game
    sg.Parent = PlayerGui
    Mobile.gui = sg

    for _, dir in ipairs(ARROW_ORDER) do
        local colors = ARROW_COLORS[dir]

        local frame = Instance.new("Frame")
        frame.AnchorPoint = Vector2.new(0.5, 0.5)
        frame.BackgroundColor3 = colors.idle
        frame.BackgroundTransparency = 0.3
        frame.BorderSizePixel = 0
        frame.Active = true
        frame.Parent = sg
        F.uiCorner(frame, UDim.new(0, 18))
        local stroke = F.uiStroke(frame, Color3.fromRGB(255, 255, 255), 2)
        stroke.Transparency = 0.5

        local grad = Instance.new("UIGradient")
        grad.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.1),
            NumberSequenceKeypoint.new(0.5, 0.35),
            NumberSequenceKeypoint.new(1, 0.15),
        })
        grad.Rotation = 90
        grad.Parent = frame

        local glow = Instance.new("Frame")
        glow.Size = UDim2.new(1, 6, 1, 6)
        glow.AnchorPoint = Vector2.new(0.5, 0.5)
        glow.Position = UDim2.new(0.5, 0, 0.5, 0)
        glow.BackgroundColor3 = colors.hit
        glow.BackgroundTransparency = 1
        glow.BorderSizePixel = 0
        glow.ZIndex = 0
        glow.Visible = false
        glow.Parent = frame
        F.uiCorner(glow, UDim.new(0, 20))

        local glyph = Instance.new("TextLabel")
        glyph.Size = UDim2.new(1, 0, 1, 0)
        glyph.BackgroundTransparency = 1
        glyph.Text = ARROW_SYMBOLS[dir]
        glyph.TextColor3 = Color3.fromRGB(255, 255, 255)
        glyph.Font = Enum.Font.GothamBold
        glyph.TextSize = 32
        glyph.ZIndex = 2
        glyph.Parent = frame

        Mobile.btns[dir] = { frame = frame, glyph = glyph, stroke = stroke, glow = glow }

        -- a finger (or the mouse, for testing) starting on this arrow
        frame.InputBegan:Connect(function(input)
            local t = input.UserInputType
            if t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseButton1 then return end
            if Mobile.touches[input] ~= nil then return end
            Mobile.touches[input] = dir
            Mobile.press(dir)
        end)
    end

    Mobile.layout()
end

-- Which arrow is under a screen point? Touch positions are measured below
-- the top bar, but these arrows ignore it, so the inset is added back first.
-- The hit area is a little bigger than the arrow, so a finger rolling across
-- doesn't fall into gaps.
function Mobile.hitTest(pos)
    local inset = Vector2.new(0, 0)
    pcall(function() inset = game:GetService("GuiService"):GetGuiInset() end)
    local p = Vector2.new(pos.X, pos.Y) + inset
    local best, bestD
    for dir, b in pairs(Mobile.btns) do
        local ap, as = b.frame.AbsolutePosition, b.frame.AbsoluteSize
        local pad = as.X * 0.12
        if p.X >= ap.X - pad and p.X <= ap.X + as.X + pad
            and p.Y >= ap.Y - pad and p.Y <= ap.Y + as.Y + pad then
            local d = (p - (ap + as / 2)).Magnitude
            if not bestD or d < bestD then best, bestD = dir, d end
        end
    end
    return best
end

-- A tracked finger moved: if it's now over a different arrow, let go of the
-- old one and press the new one, the way FNF mobile hitboxes work. Sliding
-- off every arrow releases the note; sliding back on presses again.
-- Entries hold the arrow under the finger, or false when it's between them.
function Mobile.retarget(input, pos)
    local cur = Mobile.touches[input]
    if cur == nil then return end
    local now = Mobile.hitTest(pos) or false
    if now == cur then return end
    if cur then Mobile.release(cur) end
    Mobile.touches[input] = now
    if now then Mobile.press(now) end
end

F.own(UserInputService.TouchMoved:Connect(function(touch)
    Mobile.retarget(touch, touch.Position)
end))
-- mouse testing on PC: the held button's position comes from mouse movement
F.own(UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    for tracked, _ in pairs(Mobile.touches) do
        if tracked.UserInputType == Enum.UserInputType.MouseButton1 then
            Mobile.retarget(tracked, input.Position)
        end
    end
end))

-- A finger lifting anywhere counts, so a note can never get stuck held down.
local function mobileEnded(input)
    local dir = Mobile.touches[input]
    if dir == nil then return end
    Mobile.touches[input] = nil
    if dir then Mobile.release(dir) end
end
F.own(UserInputService.InputEnded:Connect(mobileEnded))
F.own(UserInputService.TouchEnded:Connect(function(touch) mobileEnded(touch) end))

function Mobile.refresh()
    local show = Mobile.shouldShow()
    Mobile.active = show
    if show then
        if not Mobile.gui or not Mobile.gui.Parent then Mobile.build() end
        Mobile.gui.Enabled = true
        Mobile.layout()
    elseif Mobile.gui then
        -- let go of anything still held before hiding
        for input, dir in pairs(Mobile.touches) do
            if dir then Mobile.release(dir) end
            Mobile.touches[input] = nil
        end
        Mobile.held = {}
        Mobile.gui.Enabled = false
    end
    if Arrows.container then
        Arrows.container.Visible = not (show and Mobile.hideStrip)
    end
    Mobile.applyExtras(show)
    if Mobile.refreshUI then Mobile.refreshUI() end
end

function Mobile.start()
    Mobile.refresh()
    local cam = Workspace.CurrentCamera
    if cam then
        F.own(cam:GetPropertyChangedSignal("ViewportSize"):Connect(Mobile.layout))
    end
    -- plugging in a keyboard (or unplugging it) re-checks AUTO
    F.own(UserInputService:GetPropertyChangedSignal("KeyboardEnabled"):Connect(Mobile.refresh))
end

-- ============================================================
--  MENU SIZE
--  The panel is laid out at 440 x 620. On a phone that's taller
--  than the screen, so it's scaled as a whole (everything inside
--  keeps its layout) to fit, and kept on-screen when dragged.
-- ============================================================
function Menu.screen()
    local cam = Workspace.CurrentCamera
    local vs = cam and cam.ViewportSize or Vector2.new(1280, 720)
    local inset = Vector2.new(0, 0)
    pcall(function() inset = game:GetService("GuiService"):GetGuiInset() end)
    -- the panel's ScreenGui sits below the top bar, so that space isn't usable
    return vs.X, math.max(vs.Y - inset.Y, 100)
end

function Menu.targetScale()
    local W, H = Menu.screen()
    local s = Menu.scale
    if Menu.auto then
        local margin = 16
        local fit = math.min((W - margin) / Menu.W, (H - margin) / Menu.H, 1)
        s = fit * Menu.scale
    end
    return math.clamp(s, 0.3, 1.6)
end

-- Keep the whole panel visible: nudge it back if it's off an edge.
function Menu.clamp()
    local main = Menu.main
    if not main or not main.Parent or Menu.clamping then return end
    local W, H = Menu.screen()
    local size = main.AbsoluteSize
    local pos = main.Position
    local x = math.clamp(pos.X.Offset + pos.X.Scale * W, 4, math.max(4, W - size.X - 4))
    local y = math.clamp(pos.Y.Offset + pos.Y.Scale * H, 4, math.max(4, H - size.Y - 4))
    if math.abs(x - (pos.X.Offset + pos.X.Scale * W)) > 0.5 or math.abs(y - (pos.Y.Offset + pos.Y.Scale * H)) > 0.5 then
        Menu.clamping = true
        main.Position = UDim2.new(0, x, 0, y)
        Menu.clamping = false
    end
end

function Menu.fit()
    if not Menu.scaleObj or not Menu.scaleObj.Parent then return end
    Menu.current = Menu.targetScale()
    Menu.scaleObj.Scale = Menu.current
    task.defer(Menu.clamp)          -- AbsoluteSize updates next frame
    -- the tour card follows the same size
    local tour = Intro.tourGui and Intro.tourGui:FindFirstChildWhichIsA("Frame")
    local ts = tour and tour:FindFirstChildOfClass("UIScale")
    if ts then ts.Scale = Menu.current end
    if Menu.refreshUI then Menu.refreshUI() end
end

function Menu.attach(main)
    Menu.main = main
    local sc = main:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
    sc.Parent = main
    Menu.scaleObj = sc
    Menu.fit()
    -- dragged off-screen, or the panel's size changed (HIDE / SHOW): pull it back
    main:GetPropertyChangedSignal("Position"):Connect(function()
        if not Menu.clamping then task.defer(Menu.clamp) end
    end)
    main:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() task.defer(Menu.clamp) end)
    if not Menu.watching then
        Menu.watching = true
        local cam = Workspace.CurrentCamera
        if cam then F.own(cam:GetPropertyChangedSignal("ViewportSize"):Connect(Menu.fit)) end
    end
end

-- ============================================================
--  CAMERA 2.0
--  Runs after the camera's smoothing (and before snap hits and
--  chaos), so everything here lands crisply on the frame.
-- ============================================================
local function smooth01(x)
    x = math.clamp(x, 0, 1)
    return x * x * (3 - 2 * x)
end

function Cam2.kick(axis, amp)
    Cam2.shakeAxis = axis
    Cam2.shakeAmp = amp
    Cam2.shakeT = 0
    FNFCamera.settled = false
end

-- Closer when you're losing, normal when you're healthy.
function Cam2.distMul()
    if not Cam2.healthDist or not Health.enabled then return 1 end
    local hp = math.clamp(Health.display or 0.5, 0, 1)
    return Cam2.healthClosest + (1 - Cam2.healthClosest) * hp
end

Cam2.INTROS = { "SWOOP", "DOLLY", "RISE" }
Cam2.OUTROS = { "PULLBACK", "ORBIT", "CRANE" }
Cam2.SHOT_HELP = {
    SWOOP    = "Starts high behind and sweeps around into place.",
    DOLLY    = "Starts far back and glides straight in.",
    RISE     = "Starts low on the ground looking up, then rises.",
    PULLBACK = "Pulls up and away for a wide ending.",
    ORBIT    = "Circles slowly around the two of you.",
    CRANE    = "Rises high and looks down on the stage.",
}

function Cam2.play(kind)
    Cam2.shot = {
        kind = kind,
        style = (kind == "INTRO") and Cam2.introStyle or Cam2.outroStyle,
        t0 = os.clock(),
    }
    FNFCamera.settled = false
end

-- Where a shot style wants the camera, relative to the normal framing.
function Cam2.shotPos(style, focus, base, elapsed)
    local rel = base.Position - focus
    local flat = Vector3.new(rel.X, 0, rel.Z)
    local up = Vector3.new(0, 1, 0)
    if style == "SWOOP" then
        return focus + CFrame.Angles(0, math.rad(110), 0):VectorToWorldSpace(flat) * 1.8 + up * (rel.Y + 14)
    elseif style == "DOLLY" then
        return focus + rel * 2.6 + up * 4
    elseif style == "RISE" then
        return focus + flat * 1.15 + up * 0.8
    elseif style == "PULLBACK" then
        return focus + rel * 2.2 + up * 16
    elseif style == "ORBIT" then
        return focus + CFrame.Angles(0, math.rad(elapsed * Cam2.orbitDegPerSec), 0):VectorToWorldSpace(flat) * 1.4
            + up * (rel.Y + 4)
    elseif style == "CRANE" then
        return focus + flat * 0.9 + up * (rel.Y + 30)
    end
    return base.Position
end

function Cam2.shotBlend(cf, root, oroot)
    local s = Cam2.shot
    local el = os.clock() - s.t0
    local dur = math.max(Cam2.shotTime, 0.2)
    local w
    if s.kind == "INTRO" then
        if el >= dur then Cam2.shot = nil; return cf end
        w = 1 - smooth01(el / dur)                  -- starts on the shot, lands on normal
    else
        local back = 0.9
        if el < dur then w = smooth01(el / dur)                              -- fly out
        elseif el < dur + Cam2.outroHold then w = 1                          -- hold
        elseif el < dur + Cam2.outroHold + back then
            w = 1 - smooth01((el - dur - Cam2.outroHold) / back)              -- come back
        else Cam2.shot = nil; return cf end
    end
    local focus = oroot and (root.Position + oroot.Position) / 2 or root.Position
    focus = focus + Vector3.new(0, 2, 0)
    local pos = cf.Position:Lerp(Cam2.shotPos(s.style, focus, cf, el), w)
    local baseLook = cf.Position + cf.LookVector * (cf.Position - focus).Magnitude
    return CFrame.lookAt(pos, baseLook:Lerp(focus, w))
end

function Cam2.post(cf, fov, dt)
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local oChar = currentTarget and currentTarget.Character
    local oroot = oChar and oChar:FindFirstChild("HumanoidRootPart")

    -- opponent zoom-in: a lens dip plus a turn toward them, easing back out
    if Cam2.oppAmt > 0.05 then
        fov = fov - Cam2.oppAmt
        local head = oChar and (oChar:FindFirstChild("Head") or oroot)
        if head and Cam2.oppAim > 0 then
            local k = math.clamp(Cam2.oppAmt / math.max(Cam2.oppZoomPower, 1), 0, 1) * Cam2.oppAim
            local want = head.Position - cf.Position
            if want.Magnitude > 0.1 then
                cf = CFrame.lookAt(cf.Position, cf.Position + cf.LookVector:Lerp(want.Unit, k))
            end
        end
        Cam2.oppAmt = Cam2.oppAmt * math.exp(-Cam2.oppDecay * dt)
    else
        Cam2.oppAmt = 0
    end

    if Cam2.shot and root then cf = Cam2.shotBlend(cf, root, oroot) end

    -- directional shake: a quick decaying wobble along one axis
    if Cam2.shakeAmp > 0.002 then
        Cam2.shakeT = Cam2.shakeT + dt
        local o = Cam2.shakeAmp * math.sin(Cam2.shakeT * Cam2.shakeFreq)
        cf = cf * CFrame.new(Cam2.shakeAxis.X * o, Cam2.shakeAxis.Y * o, 0)
        Cam2.shakeAmp = Cam2.shakeAmp * math.exp(-Cam2.shakeDecay * dt)
    else
        Cam2.shakeAmp = 0
    end
    return cf, fov
end

-- ---- custom camera presets -----------------------------------------------
Cam2.CAM_FIELDS = { "camDistance", "camHeight", "camHorizontal", "camAngle", "camFlipped",
    "orbitSpeed", "orbitAmp", "dutch", "handheld", "lead", "pitchBias", "settleEnabled",
    "settleAfter", "snapHits", "nudgeScale", "tiltScale", "punchScale", "returnSpeed",
    "beatPower", "beatAccent", "dirBoost", "dirHold", "mode" }
Cam2.OWN_FIELDS = { "pulseEvery", "beatShake", "oppZoom", "oppZoomPower", "oppAim",
    "dirShake", "dirShakePower", "healthDist", "healthClosest" }

function Cam2.capture()
    local data = { cam = {}, own = {}, fov = CAM_CFG.BaseFOV }
    for _, k in ipairs(Cam2.CAM_FIELDS) do
        local v = FNFCamera[k]
        local t = type(v)
        if t == "number" or t == "boolean" or t == "string" then data.cam[k] = v end
    end
    for _, k in ipairs(Cam2.OWN_FIELDS) do data.own[k] = Cam2[k] end
    return data
end

function Cam2.applyPreset(data)
    if type(data) ~= "table" then return end
    for k, v in pairs(data.cam or {}) do
        if table.find(Cam2.CAM_FIELDS, k) and (FNFCamera[k] == nil or type(FNFCamera[k]) == type(v)) then
            FNFCamera[k] = v
        end
    end
    for k, v in pairs(data.own or {}) do
        if table.find(Cam2.OWN_FIELDS, k) and type(Cam2[k]) == type(v) then Cam2[k] = v end
    end
    if type(data.fov) == "number" then CAM_CFG.BaseFOV = data.fov end
    FNFCamera.currentCFrame = nil      -- cut cleanly into it
    FNFCamera.settled = false
end

function Cam2.savePreset(name)
    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then name = "My shot " .. (#Cam2.presets + 1) end
    for _, p in ipairs(Cam2.presets) do
        if p.name == name then p.data = Cam2.capture(); return name end   -- same name: overwrite
    end
    table.insert(Cam2.presets, { name = name, data = Cam2.capture() })
    return name
end

-- picking an opponent can play the intro; wrapped at launch, once
function Cam2.hookOpponent()
    if Cam2.hooked or not F.pickOpponent then return end
    Cam2.hooked = true
    local base = F.pickOpponent
    F.pickOpponent = function(player, ...)
        local r = base(player, ...)
        if player and Cam2.introOnOpponent then Cam2.play("INTRO") end
        return r
    end
end

-- ============================================================
--  CUTSCENE MODE
--  Hides the gameplay UI (and Roblox's own UI if you like), adds
--  cinematic bars, and lets the camera and your animations play
--  like a music video. Press the key again, or tap the top-right
--  corner on mobile, to come back.
-- ============================================================
Cutscene.HIDE = { "FNFInjectorGui", "FNFArrowHud", "FNFHealthBar", "FNFKeybindList",
    "FNFMobileNotes", "FNFTour", "FNFWind", "FNFResult" }

function Cutscene.enter()
    if Cutscene.active then return end
    Cutscene.active = true
    Cutscene.saved, Cutscene.core = {}, {}

    for _, name in ipairs(Cutscene.HIDE) do
        local g = PlayerGui:FindFirstChild(name)
        if g and g:IsA("ScreenGui") then
            Cutscene.saved[g] = g.Enabled
            g.Enabled = false
        end
    end
    if Cutscene.hideRoblox then
        local SG = game:GetService("StarterGui")
        for _, t in ipairs(Enum.CoreGuiType:GetEnumItems()) do
            if t ~= Enum.CoreGuiType.All then
                local ok, on = pcall(function() return SG:GetCoreGuiEnabled(t) end)
                if ok then
                    Cutscene.core[t] = on
                    pcall(function() SG:SetCoreGuiEnabled(t, false) end)
                end
            end
        end
    end

    local sg = F.own(Instance.new("ScreenGui"))
    sg.Name = "FNFCutscene"
    sg.IgnoreGuiInset = true
    sg.ResetOnSpawn = false
    sg.DisplayOrder = F.silZ(120)
    sg.Parent = PlayerGui
    Cutscene.gui = sg

    if Cutscene.bars then
        for i, anchorY in ipairs({ 0, 1 }) do
            local bar = Instance.new("Frame")
            bar.Name = "Bar" .. i
            bar.AnchorPoint = Vector2.new(0, anchorY)
            bar.Position = UDim2.new(0, 0, anchorY, 0)
            bar.Size = UDim2.new(1, 0, 0, 0)
            bar.BackgroundColor3 = Color3.new(0, 0, 0)
            bar.BorderSizePixel = 0
            bar.Parent = sg
            TweenService:Create(bar, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                { Size = UDim2.new(1, 0, 0.11, 0) }):Play()
        end
    end

    -- a way out without a keyboard: tap the top-right corner
    local exitBtn = Instance.new("TextButton")
    exitBtn.AnchorPoint = Vector2.new(1, 0)
    exitBtn.Position = UDim2.new(1, 0, 0, 0)
    exitBtn.Size = UDim2.new(0, 90, 0, 90)
    exitBtn.BackgroundTransparency = 1
    exitBtn.Text = ""
    exitBtn.Parent = sg
    exitBtn.MouseButton1Click:Connect(Cutscene.exit)

    local hint = Instance.new("TextLabel")
    hint.AnchorPoint = Vector2.new(1, 0)
    hint.Position = UDim2.new(1, -14, 0, 14)
    hint.Size = UDim2.new(0, 320, 0, 20)
    hint.BackgroundTransparency = 1
    hint.Text = "CUTSCENE — press " .. Cutscene.key .. " or tap here to exit"
    hint.TextColor3 = Color3.fromRGB(235, 235, 245)
    hint.Font = Enum.Font.GothamBold
    hint.TextSize = 12
    hint.TextXAlignment = Enum.TextXAlignment.Right
    hint.TextStrokeTransparency = 0.5
    hint.Parent = sg
    task.delay(2.5, function()
        if hint.Parent then TweenService:Create(hint, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play() end
    end)

    if Cutscene.refreshUI then Cutscene.refreshUI() end
end

function Cutscene.exit()
    if not Cutscene.active then return end
    Cutscene.active = false
    for g, was in pairs(Cutscene.saved) do
        if g and g.Parent then g.Enabled = was end
    end
    local SG = game:GetService("StarterGui")
    for t, on in pairs(Cutscene.core) do
        pcall(function() SG:SetCoreGuiEnabled(t, on) end)
    end
    Cutscene.saved, Cutscene.core = {}, {}

    local sg = Cutscene.gui
    Cutscene.gui = nil
    if sg then
        for _, c in ipairs(sg:GetChildren()) do
            if c:IsA("Frame") then
                TweenService:Create(c, TweenInfo.new(0.35, Enum.EasingStyle.Quint), { Size = UDim2.new(1, 0, 0, 0) }):Play()
            end
        end
        task.delay(0.4, function() sg:Destroy() end)
    end
    if Cutscene.refreshUI then Cutscene.refreshUI() end
end

function Cutscene.toggle()
    if Cutscene.active then Cutscene.exit() else Cutscene.enter() end
end

-- ============================================================
--  SPOTLIGHT
--  Darkens the screen except a soft capsule of light around you
--  and your opponent, following you both on screen. Works on its
--  own or on top of silhouette mode.
-- ============================================================
function SilFX.buildSpot()
    local old = PlayerGui:FindFirstChild("FNFSpotlight")
    if old then old:Destroy() end
    local sg = F.own(Instance.new("ScreenGui"))
    sg.Name = "FNFSpotlight"
    sg.IgnoreGuiInset = true          -- matches the camera's full-screen coordinates
    sg.ResetOnSpawn = false
    sg.DisplayOrder = F.silZ(40)
    sg.Parent = PlayerGui
    SilFX.spotGui = sg
    -- three nested capsules: a strokes-only frame darkens everything OUTSIDE
    -- it, so a huge stroke on the outer one is the dark, and the two inner
    -- rings step the edge down softly instead of a hard cut
    SilFX.spotRings = {}
    for i, spec in ipairs({ { grow = 0, thick = 40, share = 0.35 },
                            { grow = 80, thick = 40, share = 0.7 },
                            { grow = 160, thick = 4000, share = 1 } }) do
        local f = Instance.new("Frame")
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.BackgroundTransparency = 1
        f.Parent = sg
        F.uiCorner(f, UDim.new(1, 0))
        local s = Instance.new("UIStroke")
        s.Color = Color3.new(0, 0, 0)
        s.Thickness = spec.thick
        s.Parent = f
        SilFX.spotRings[i] = { frame = f, stroke = s, grow = spec.grow, share = spec.share }
    end
end

function SilFX.stepSpot()
    if not SilFX.spotlight then
        if SilFX.spotGui then SilFX.spotGui.Enabled = false end
        return
    end
    if not SilFX.spotGui or not SilFX.spotGui.Parent then SilFX.buildSpot() end
    local cam = Workspace.CurrentCamera
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not cam or not root then SilFX.spotGui.Enabled = false; return end

    local function project(p)
        local v, on = cam:WorldToViewportPoint(p)
        return Vector2.new(v.X, v.Y), v.Z > 0
    end
    local a, aOk = project(root.Position)
    local top = project(root.Position + Vector3.new(0, 3, 0))
    local bottom = project(root.Position - Vector3.new(0, 3, 0))
    local h = math.max(60, math.abs(top.Y - bottom.Y)) * 1.35

    local center, w = a, h * 0.9
    local oroot = currentTarget and currentTarget.Character and currentTarget.Character:FindFirstChild("HumanoidRootPart")
    if oroot then
        local b, bOk = project(oroot.Position)
        if bOk then
            center = (a + b) / 2
            w = math.abs(a.X - b.X) + h * 0.9
            h = math.max(h, math.abs(a.Y - b.Y) + h)
        end
    end
    SilFX.spotGui.Enabled = aOk
    for _, r in ipairs(SilFX.spotRings) do
        r.frame.Position = UDim2.new(0, center.X, 0, center.Y)
        r.frame.Size = UDim2.new(0, w + r.grow, 0, h + r.grow)
        r.stroke.Transparency = 1 - SilFX.spotDim * r.share
    end
end

-- ============================================================
--  CHARACTER PORTRAITS
--  Your avatar's headshot and your opponent's, on the health bar
--  icons. A custom icon ID still wins if you've set one.
-- ============================================================
function Health.headshot(userId)
    if not userId then return "" end
    local ok, img = pcall(function()
        return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
    end)
    return (ok and img) or ""
end

function Health.refreshPortraits()
    task.spawn(function()
        Health.portraitP = Health.portraits and Health.headshot(LocalPlayer.UserId) or ""
        Health.portraitO = (Health.portraits and currentTarget) and Health.headshot(currentTarget.UserId) or ""
        Health.portraitFor = currentTarget
        Health.setIcons(Health.playerIcon, Health.oppIcon)
    end)
end

function Health.startPortraits()
    if Health.portraitLoop then return end
    Health.portraitLoop = true
    Health.refreshPortraits()
    task.spawn(function()
        while F.alive do
            task.wait(1)
            if Health.portraits and Health.portraitFor ~= currentTarget then Health.refreshPortraits() end
        end
    end)
end

-- ============================================================
--  MOBILE EXTRAS: haptics, landscape lock, tidy desktop UI
-- ============================================================
function Mobile.hapticSupport()
    local HS = game:GetService("HapticService")
    local ok, sup = pcall(function() return HS:IsVibrationSupported(Enum.UserInputType.Touch) end)
    if not ok or not sup then return nil end
    for _, m in ipairs({ Enum.VibrationMotor.Small, Enum.VibrationMotor.Large }) do
        local okM, on = pcall(function() return HS:IsMotorSupported(Enum.UserInputType.Touch, m) end)
        if okM and on then return m end
    end
    return nil
end

function Mobile.buzz()
    if not Mobile.haptics then return end
    local motor = Mobile.hapticMotor
    if motor == nil then
        motor = Mobile.hapticSupport() or false
        Mobile.hapticMotor = motor
    end
    if not motor then return end
    local HS = game:GetService("HapticService")
    pcall(function() HS:SetMotor(Enum.UserInputType.Touch, motor, 0.7) end)
    task.delay(0.035, function()
        pcall(function() HS:SetMotor(Enum.UserInputType.Touch, motor, 0) end)
    end)
end

function Mobile.applyExtras(show)
    -- landscape lock
    if show and Mobile.landscape then
        if Mobile.prevOrientation == nil then Mobile.prevOrientation = PlayerGui.ScreenOrientation end
        pcall(function() PlayerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor end)
    elseif Mobile.prevOrientation ~= nil then
        pcall(function() PlayerGui.ScreenOrientation = Mobile.prevOrientation end)
        Mobile.prevOrientation = nil
    end
    -- desktop-only UI: the keyboard cheat sheet is pointless on a phone, and
    -- the panel starts folded so the stage is visible (once per session)
    if show and Mobile.hideDesktop then
        if Keys.overlayOn then Keys.setOverlay(false) end
        if not Mobile.didFold and F.setPanelOpen then
            Mobile.didFold = true
            F.setPanelOpen(false)
        end
    end
end

-- ============================================================
--  CHAOS CAMERA FX — unstable, aggressive, corrupted camera
--
--  Roblox exposes no post-process shader hooks, so true barrel
--  distortion / screen warping of the rendered frame is not
--  possible. Everything below approximates that look with the
--  tools that DO exist: violent FOV pumping, camera roll, dolly
--  along the view axis, ColorCorrection spikes, and screen-space
--  GUI overlays. All overlays are ZIndex-capped at 200.
-- ============================================================
function Chaos.build()
    local old = PlayerGui:FindFirstChild("FNFChaosFX")
    if old then old:Destroy() end

    local sg = F.own(Instance.new("ScreenGui"))
    sg.Name = "FNFChaosFX"; sg.IgnoreGuiInset = true
    sg.ResetOnSpawn = false; sg.DisplayOrder = F.silZ(160)
    sg.Enabled = Chaos.enabled
    sg.Parent = PlayerGui
    Chaos.gui = sg
    Chaos.layers = {}

    -- chromatic / RGB split: three tinted sheets we slide apart
    Chaos.layers.rgb = {}
    local tints = { Color3.fromRGB(255,0,60), Color3.fromRGB(0,255,120), Color3.fromRGB(60,80,255) }
    for i, c in ipairs(tints) do
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 60, 1, 60)
        f.Position = UDim2.new(0, -30, 0, -30)
        f.BackgroundColor3 = c
        f.BackgroundTransparency = 1
        f.BorderSizePixel = 0
        f.ZIndex = F.silZ(150 + i)
        f.Parent = sg
        Chaos.layers.rgb[i] = f
    end

    -- lens-squeeze vignette: four gradient edges that crush inward
    Chaos.layers.vig = {}
    local edges = {
        { UDim2.new(1,0,0,120), UDim2.new(0,0,0,0), Vector2.new(0,0), 90  },
        { UDim2.new(1,0,0,120), UDim2.new(0,0,1,0), Vector2.new(0,1), 270 },
        { UDim2.new(0,120,1,0), UDim2.new(0,0,0,0), Vector2.new(0,0), 0   },
        { UDim2.new(0,120,1,0), UDim2.new(1,0,0,0), Vector2.new(1,0), 180 },
    }
    for i, e in ipairs(edges) do
        local f = Instance.new("Frame")
        f.Size = e[1]; f.Position = e[2]; f.AnchorPoint = e[3]
        f.BackgroundColor3 = Color3.new(0,0,0)
        f.BackgroundTransparency = 1
        f.BorderSizePixel = 0
        f.ZIndex = F.silZ(160)
        f.Parent = sg
        local g = Instance.new("UIGradient")
        g.Rotation = e[4]
        g.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        })
        g.Parent = f
        Chaos.layers.vig[i] = f
    end

    -- scanline sheet (only shown during glitch spikes)
    local scan = Instance.new("Frame")
    scan.Size = UDim2.new(1, 0, 1, 12); scan.BackgroundTransparency = 1
    scan.BorderSizePixel = 0; scan.ClipsDescendants = true
    scan.ZIndex = F.silZ(170); scan.Visible = false; scan.Parent = sg
    for y = 0, 1300, 3 do
        local line = Instance.new("Frame")
        line.Size = UDim2.new(1,0,0,1); line.Position = UDim2.new(0,0,0,y)
        line.BackgroundColor3 = Color3.new(0,0,0)
        line.BackgroundTransparency = 0.45
        line.BorderSizePixel = 0; line.ZIndex = F.silZ(170); line.Parent = scan
    end
    Chaos.layers.scan = scan

    -- torn-block container
    local tear = Instance.new("Frame")
    tear.Size = UDim2.new(1,0,1,0); tear.BackgroundTransparency = 1
    tear.BorderSizePixel = 0; tear.ClipsDescendants = true
    tear.ZIndex = F.silZ(180); tear.Parent = sg
    Chaos.layers.tear = tear

    -- flash sheet
    local flash = Instance.new("Frame")
    flash.Size = UDim2.new(1,0,1,0); flash.BackgroundColor3 = Color3.new(1,1,1)
    flash.BackgroundTransparency = 1; flash.BorderSizePixel = 0
    flash.ZIndex = F.silZ(190); flash.Parent = sg
    Chaos.layers.flash = flash

    -- colour grade driver for red/white spikes
    local old2 = Lighting:FindFirstChild("FNFChaosCC")
    if old2 then old2:Destroy() end
    local cc = F.own(Instance.new("ColorCorrectionEffect"))
    cc.Name = "FNFChaosCC"
    cc.Brightness = 0; cc.Contrast = 0; cc.Saturation = 0
    cc.Parent = Lighting
    Chaos.cc = cc
end

-- Short red/white blowout. Kept brief on purpose.
function Chaos.flashPulse(color, strength)
    local f = Chaos.layers and Chaos.layers.flash
    strength = (strength or 0.8) * Chaos.flash
    if f then
        f.BackgroundColor3 = color or Color3.new(1,1,1)
        f.BackgroundTransparency = math.clamp(1 - strength, 0, 1)
        TweenService:Create(f, TweenInfo.new(0.15, Enum.EasingStyle.Quint), { BackgroundTransparency = 1 }):Play()
    end
    Chaos.ccSpike = math.max(Chaos.ccSpike, strength)
    Chaos.rgbSplit = math.max(Chaos.rgbSplit, strength * 0.9)
end

-- Frame tears into offset blocks and shifts sideways.
function Chaos.glitchBurst(dur)
    if not Chaos.enabled then return end
    local tear = Chaos.layers and Chaos.layers.tear
    if not tear then return end
    dur = (dur or 0.2) * Chaos.glitch
    local wasRunning = os.clock() < Chaos.tearUntil
    Chaos.tearUntil = math.max(Chaos.tearUntil, os.clock() + dur)
    if wasRunning then return end

    task.spawn(function()
        while os.clock() < Chaos.tearUntil do
            for _, c in ipairs(tear:GetChildren()) do c:Destroy() end
            for i = 1, math.random(3, 7) do
                local blk = Instance.new("Frame")
                blk.Size = UDim2.new(1, math.random(30, 140), 0, math.random(6, 58))
                blk.Position = UDim2.new(0, math.random(-100, 100), math.random(), 0)
                if math.random() < 0.35 then
                    blk.BackgroundColor3 = Color3.fromRGB(math.random(180,255), math.random(0,80), math.random(120,255))
                    blk.BackgroundTransparency = 0.45 + math.random() * 0.3
                else
                    blk.BackgroundColor3 = Color3.fromRGB(math.random(0,35), math.random(0,35), math.random(0,55))
                    blk.BackgroundTransparency = 0.3 + math.random() * 0.4
                end
                blk.BorderSizePixel = 0
                blk.ZIndex = F.silZ(180)
                blk.Parent = tear
            end
            -- hard lateral snap of the real frame, so the tear reads as motion
            Chaos.kickX = Chaos.kickX + (math.random() - 0.5) * 3.6 * Chaos.glitch
            Chaos.rgbSplit = math.max(Chaos.rgbSplit, 0.85)
            task.wait(0.03 + math.random() * 0.04)
        end
        for _, c in ipairs(tear:GetChildren()) do c:Destroy() end
    end)
end

-- Camera gets sucked toward the scene centre, then fires outward.
function Chaos.tunnelPull(dur)
    if not Chaos.enabled then return end
    Chaos.tunnelDur = dur or 0.85
    Chaos.tunnelUntil = os.clock() + Chaos.tunnelDur
    Chaos.tunnelFired = false
    Chaos.glitchBurst(0.12)
end

-- Every note press routes through here. power ~0.3 (light) to ~2 (huge).
function Chaos.hit(power, dir)
    if not Chaos.enabled then return end
    power = (power or 1) * Chaos.master
    local now = os.clock()

    -- punch in hard; the spring overshoots past neutral then snaps back
    Chaos.zoomVel = Chaos.zoomVel - 46 * power * Chaos.zoomPunch
    Chaos.dollyVel = Chaos.dollyVel - 28 * power * Chaos.zoomPunch

    local s = 2.5 * power * Chaos.shake
    if dir == "LEFT" then
        Chaos.kickX = Chaos.kickX - s; Chaos.rollVel = Chaos.rollVel + 7 * power
    elseif dir == "RIGHT" then
        Chaos.kickX = Chaos.kickX + s; Chaos.rollVel = Chaos.rollVel - 7 * power
    elseif dir == "UP" then
        Chaos.kickY = Chaos.kickY + s * 0.85; Chaos.rollVel = Chaos.rollVel + (math.random()-0.5) * 5
    elseif dir == "DOWN" then
        Chaos.kickY = Chaos.kickY - s * 0.85; Chaos.rollVel = Chaos.rollVel + (math.random()-0.5) * 5
    else
        Chaos.kickX = Chaos.kickX + (math.random() - 0.5) * 2 * s
    end

    Chaos.impact = math.min(Chaos.impact + 0.55 * power, 1.6)
    Chaos.warpPhase = Chaos.warpPhase + 1.3 * power

    -- two notes almost together = double-note blowout
    if now - Chaos.lastHit < 0.07 then
        Chaos.flashPulse(Color3.fromRGB(255, 70, 70), 1)
        Chaos.glitchBurst(0.26)
        Chaos.zoomVel = Chaos.zoomVel - 32
        Chaos.rollVel = Chaos.rollVel + (math.random() < 0.5 and -1 or 1) * 17
    elseif power >= 1.3 then
        Chaos.glitchBurst(0.16 * power)
    end
    Chaos.lastHit = now

    -- periodic tunnel transition on a long streak
    Chaos.hitCount = Chaos.hitCount + 1
    if Chaos.hitCount % 18 == 0 then Chaos.tunnelPull(0.8) end
end

-- Deliberate "major impact" beat: overshoot zoom, roll, flash, tear.
function Chaos.bigImpact(power)
    if not Chaos.enabled then return end
    power = power or 1.7
    Chaos.zoomVel = Chaos.zoomVel - 70 * power * Chaos.zoomPunch
    Chaos.dollyVel = Chaos.dollyVel - 46 * power * Chaos.zoomPunch
    Chaos.rollVel = Chaos.rollVel + (math.random() < 0.5 and -1 or 1) * 22 * power
    Chaos.kickX = Chaos.kickX + (math.random() - 0.5) * 6 * Chaos.shake
    Chaos.kickY = Chaos.kickY + (math.random() - 0.5) * 4 * Chaos.shake
    Chaos.impact = math.min(Chaos.impact + 1.2 * power, 2)
    Chaos.flashPulse(Color3.fromRGB(255, 60, 60), 1.1)
    Chaos.glitchBurst(0.32)
end

function Chaos.updateOverlays()
    local L = Chaos.layers
    if not L then return end
    local split = Chaos.rgbSplit * Chaos.master

    if L.rgb then
        for i, f in ipairs(L.rgb) do
            local d = (i == 1 and -1) or (i == 2 and 0.45) or 1
            f.Position = UDim2.new(0, -30 + d * split * 28, 0, -30 + d * split * 8)
            f.BackgroundTransparency = 1 - math.clamp(split * 0.22, 0, 0.3)
        end
    end

    if L.vig then
        local v = math.clamp(Chaos.impact * 0.5 * Chaos.warp, 0, 0.7)
        local squeeze = 120 + Chaos.impact * 100
        for i, f in ipairs(L.vig) do
            f.BackgroundTransparency = 1 - v
            if i <= 2 then f.Size = UDim2.new(1, 0, 0, squeeze)
            else f.Size = UDim2.new(0, squeeze, 1, 0) end
        end
    end

    if L.scan then
        local on = (split > 0.25) or (Chaos.impact > 0.85)
        L.scan.Visible = on
        if on then L.scan.Position = UDim2.new(0, 0, 0, (os.clock() * 260) % 3 - 6) end
    end

    if Chaos.cc then
        local s = Chaos.ccSpike
        Chaos.cc.Brightness = s * 0.22
        Chaos.cc.Contrast   = s * 0.75 + Chaos.impact * 0.22
        Chaos.cc.Saturation = s * 1.1 - Chaos.impact * 0.25
        Chaos.cc.TintColor  = Color3.new(1, 1 - s * 0.22, 1 - s * 0.22)
    end
end

-- Called from CameraSystem:_update AFTER smoothing, so punches stay snappy.
function Chaos.apply(cf, fov, dt)
    if not Chaos.enabled then return cf, fov end
    dt = math.clamp(dt, 0, 1/20)
    local now = os.clock()

    -- springs
    Chaos.zoomVel  = Chaos.zoomVel  + (-230 * Chaos.zoomPos  - 16 * Chaos.zoomVel)  * dt
    Chaos.zoomPos  = Chaos.zoomPos  + Chaos.zoomVel  * dt
    Chaos.dollyVel = Chaos.dollyVel + (-155 * Chaos.dollyPos - 13 * Chaos.dollyVel) * dt
    Chaos.dollyPos = Chaos.dollyPos + Chaos.dollyVel * dt
    Chaos.rollVel  = Chaos.rollVel  + (-195 * Chaos.rollPos  - 15 * Chaos.rollVel)  * dt
    Chaos.rollPos  = Chaos.rollPos  + Chaos.rollVel  * dt

    -- envelopes decay
    local kd = 1 - math.exp(-11 * dt)
    Chaos.kickX = Chaos.kickX - Chaos.kickX * kd
    Chaos.kickY = Chaos.kickY - Chaos.kickY * kd
    Chaos.impact   = math.max(0, Chaos.impact   - dt * 2.1)
    Chaos.rgbSplit = math.max(0, Chaos.rgbSplit - dt * 3.4)
    Chaos.ccSpike  = math.max(0, Chaos.ccSpike  - dt * 4.2)

    -- irregular shake: two noise octaves plus random jitter at high impact
    local amp = (0.3 + Chaos.impact * 1.55) * Chaos.shake * Chaos.master
    local t = now * 27
    local sx = (math.noise(t, Chaos.seed) + math.noise(t * 2.7, Chaos.seed + 11) * 0.5) * amp
    local sy = (math.noise(t, Chaos.seed + 40) + math.noise(t * 3.1, Chaos.seed + 51) * 0.5) * amp * 0.8
    local jitter = (Chaos.impact > 0.55) and (math.random() - 0.5) * amp * 0.9 or 0

    -- readability clamp — the character never leaves frame
    local maxOff = 3.4 * Chaos.readability
    local offX = math.clamp(sx + Chaos.kickX + jitter, -maxOff, maxOff)
    local offY = math.clamp(sy + Chaos.kickY, -maxOff, maxOff)

    -- warp: FOV flex reads as lens breathing / barrel-ish pull
    Chaos.warpPhase = Chaos.warpPhase + dt * (6 + Chaos.impact * 27)
    local warp = math.sin(Chaos.warpPhase) * (1.4 + Chaos.impact * 9) * Chaos.warp

    -- tunnel: pulled toward centre, then fired outward
    local tunnelDolly, tunnelFov = 0, 0
    if Chaos.tunnelUntil > now then
        local a = 1 - ((Chaos.tunnelUntil - now) / math.max(Chaos.tunnelDur, 0.01))
        local curve = math.sin(a * math.pi)
        tunnelDolly = -curve * 9
        tunnelFov   = curve * 36 * Chaos.warp
        Chaos.rgbSplit = math.max(Chaos.rgbSplit, curve * 0.55)
        if a > 0.97 and not Chaos.tunnelFired then
            Chaos.tunnelFired = true
            Chaos.dollyVel = Chaos.dollyVel + 60
            Chaos.flashPulse(Color3.new(1,1,1), 0.7)
        end
    end

    -- rotation: sprung roll plus small pitch/yaw wobble
    local roll  = math.rad(Chaos.rollPos + math.noise(t * 0.6, Chaos.seed + 70) * 3.5 * Chaos.impact * Chaos.shake)
    local pitch = math.rad(math.noise(t * 0.9, Chaos.seed + 90)  * 2.2 * Chaos.impact * Chaos.shake)
    local yaw   = math.rad(math.noise(t * 0.8, Chaos.seed + 120) * 2.2 * Chaos.impact * Chaos.shake)

    cf = cf * CFrame.new(offX, offY, Chaos.dollyPos + tunnelDolly) * CFrame.Angles(pitch, yaw, roll)
    local fovOut = math.clamp(fov + Chaos.zoomPos + warp + tunnelFov, 18, 120)

    Chaos.updateOverlays()
    return cf, fovOut
end

function Chaos.setEnabled(state)
    Chaos.enabled = state
    if state then
        if not Chaos.gui or not Chaos.gui.Parent then Chaos.build() end
        Chaos.gui.Enabled = true
        if not Chaos.beatThread then
            Chaos.beatThread = task.spawn(function()
                while Chaos.enabled do
                    task.wait(60 / math.max(40, StatusState.bpm or 100))
                    if Chaos.enabled and Chaos.beatSync then
                        Chaos.beatCount = (Chaos.beatCount + 1) % 4
                        Chaos.hit(Chaos.beatCount == 0 and 0.8 or 0.28)
                    end
                end
                Chaos.beatThread = nil
            end)
        end
    else
        if Chaos.gui then Chaos.gui.Enabled = false end
        if Chaos.cc then
            Chaos.cc.Brightness = 0; Chaos.cc.Contrast = 0
            Chaos.cc.Saturation = 0; Chaos.cc.TintColor = Color3.new(1,1,1)
        end
        Chaos.zoomPos, Chaos.zoomVel = 0, 0
        Chaos.dollyPos, Chaos.dollyVel = 0, 0
        Chaos.rollPos, Chaos.rollVel = 0, 0
        Chaos.kickX, Chaos.kickY = 0, 0
        Chaos.impact, Chaos.rgbSplit, Chaos.ccSpike = 0, 0, 0
    end
end

function Chaos.applyPreset(name)
    local p = ({
        Calm      = { master=0.45, shake=0.5, zoomPunch=0.5, warp=0.3, glitch=0.2, flash=0.4, readability=1.2, beatSync=false },
        Intense   = { master=1,    shake=1,   zoomPunch=1,   warp=0.8, glitch=0.7, flash=0.9, readability=1,   beatSync=true  },
        Chaotic   = { master=1.5,  shake=1.5, zoomPunch=1.4, warp=1.4, glitch=1.3, flash=1.2, readability=0.8, beatSync=true  },
        Corrupted = { master=1.8,  shake=1.7, zoomPunch=1.6, warp=1.8, glitch=2,   flash=1.5, readability=0.7, beatSync=true  },
    })[name]
    if not p then return end
    for k, v in pairs(p) do Chaos[k] = v end
    F.notify("Chaos preset: " .. name, "success")
end

-- ============================================================
--  INTRO TRANSITIONS — 5 FNF-style song intro effects
-- ============================================================
function F.playIntroTransition(name)
    local sg = F.own(Instance.new("ScreenGui"))
    sg.Name = "FNFTransition"; sg.IgnoreGuiInset = true
    sg.DisplayOrder = F.silZ(200); sg.ResetOnSpawn = false
    sg.Parent = PlayerGui

    if name == "COUNTDOWN" then
        task.spawn(function()
            local texts = { "3", "2", "1", "GO!" }
            local colors = {
                Color3.fromRGB(255, 80, 180),
                Color3.fromRGB(0, 200, 255),
                Color3.fromRGB(255, 200, 60),
                Color3.fromRGB(80, 255, 120),
            }
            for i, txt in ipairs(texts) do
                local lbl = Instance.new("TextLabel")
                lbl.Size = UDim2.new(1, 0, 1, 0)
                lbl.BackgroundTransparency = 1
                lbl.Text = txt; lbl.TextColor3 = colors[i]
                lbl.Font = Enum.Font.GothamBlack; lbl.TextSize = 120
                lbl.TextTransparency = 0; lbl.TextStrokeTransparency = 0.5
                lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
                lbl.ZIndex = F.silZ(190)
                lbl.Parent = sg
                lbl.TextSize = 40
                TweenService:Create(lbl, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                    TextSize = 140
                }):Play()
                task.wait(0.45)
                TweenService:Create(lbl, TweenInfo.new(0.15), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
                task.wait(0.2)
                lbl:Destroy()
            end
            task.wait(0.3); sg:Destroy()
        end)

    elseif name == "WIPE" then
        task.spawn(function()
            local wipe = Instance.new("Frame")
            wipe.Size = UDim2.new(3, 0, 3, 0)
            wipe.Position = UDim2.new(-1, 0, -1, 0)
            wipe.Rotation = -30
            wipe.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            wipe.BorderSizePixel = 0; wipe.ZIndex = F.silZ(190); wipe.Parent = sg
            local stripe = Instance.new("Frame")
            stripe.Size = UDim2.new(1, 0, 0, 8)
            stripe.Position = UDim2.new(0, 0, 1, 0); stripe.AnchorPoint = Vector2.new(0, 1)
            stripe.BackgroundColor3 = Color3.fromRGB(255, 80, 180)
            stripe.BorderSizePixel = 0; stripe.ZIndex = F.silZ(191); stripe.Parent = wipe
            task.wait(0.3)
            TweenService:Create(wipe, TweenInfo.new(0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
                Position = UDim2.new(2, 0, -1, 0)
            }):Play()
            task.wait(0.8); sg:Destroy()
        end)

    elseif name == "PIXELATE" then
        task.spawn(function()
            local GRID = 12
            local cells = {}
            for gx = 0, GRID - 1 do
                for gy = 0, GRID - 1 do
                    local cell = Instance.new("Frame")
                    cell.Size = UDim2.new(1/GRID, 2, 1/GRID, 2)
                    cell.Position = UDim2.new(gx/GRID, 0, gy/GRID, 0)
                    cell.BackgroundColor3 = Color3.fromRGB(math.random(0, 20), math.random(0, 10), math.random(10, 30))
                    cell.BorderSizePixel = 0; cell.ZIndex = F.silZ(190); cell.Parent = sg
                    table.insert(cells, cell)
                end
            end
            task.wait(0.5)
            local order = {}
            for i = 1, #cells do order[i] = i end
            for i = #order, 2, -1 do
                local j = math.random(1, i)
                order[i], order[j] = order[j], order[i]
            end
            for idx, ci in ipairs(order) do
                local cell = cells[ci]
                if cell then
                    TweenService:Create(cell, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
                end
                if idx % 6 == 0 then task.wait(0.03) end
            end
            task.wait(0.4); sg:Destroy()
        end)

    elseif name == "FLASH" then
        task.spawn(function()
            local flash = Instance.new("Frame")
            flash.Size = UDim2.new(1, 0, 1, 0)
            flash.BackgroundColor3 = Color3.new(1, 1, 1)
            flash.BackgroundTransparency = 0
            flash.BorderSizePixel = 0; flash.ZIndex = F.silZ(190); flash.Parent = sg
            local title = Instance.new("TextLabel")
            title.Size = UDim2.new(1, 0, 0, 60); title.Position = UDim2.new(0, 0, 0.4, 0)
            title.BackgroundTransparency = 1; title.Text = "🎵 READY?"
            title.TextColor3 = Color3.fromRGB(255, 80, 180)
            title.Font = Enum.Font.GothamBlack; title.TextSize = 50
            title.TextTransparency = 1; title.ZIndex = F.silZ(191); title.Parent = flash
            task.wait(0.1)
            TweenService:Create(title, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
            task.wait(0.8)
            TweenService:Create(flash, TweenInfo.new(0.05), { BackgroundTransparency = 0 }):Play()
            task.wait(0.1)
            TweenService:Create(flash, TweenInfo.new(0.5, Enum.EasingStyle.Quint), { BackgroundTransparency = 1 }):Play()
            TweenService:Create(title, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
            task.wait(0.6); sg:Destroy()
        end)

    elseif name == "SPLIT" then
        task.spawn(function()
            local topHalf = Instance.new("Frame")
            topHalf.Size = UDim2.new(1, 0, 0.5, 0); topHalf.Position = UDim2.new(0, 0, 0, 0)
            topHalf.BackgroundColor3 = Color3.fromRGB(10, 5, 20); topHalf.BorderSizePixel = 0
            topHalf.ZIndex = F.silZ(190); topHalf.Parent = sg
            local topLine = Instance.new("Frame")
            topLine.Size = UDim2.new(1, 0, 0, 4); topLine.Position = UDim2.new(0, 0, 1, -4)
            topLine.BackgroundColor3 = Color3.fromRGB(255, 80, 180); topLine.BorderSizePixel = 0
            topLine.ZIndex = F.silZ(191); topLine.Parent = topHalf

            local botHalf = Instance.new("Frame")
            botHalf.Size = UDim2.new(1, 0, 0.5, 0); botHalf.Position = UDim2.new(0, 0, 0.5, 0)
            botHalf.BackgroundColor3 = Color3.fromRGB(10, 5, 20); botHalf.BorderSizePixel = 0
            botHalf.ZIndex = F.silZ(190); botHalf.Parent = sg
            local botLine = Instance.new("Frame")
            botLine.Size = UDim2.new(1, 0, 0, 4); botLine.Position = UDim2.new(0, 0, 0, 0)
            botLine.BackgroundColor3 = Color3.fromRGB(0, 200, 255); botLine.BorderSizePixel = 0
            botLine.ZIndex = F.silZ(191); botLine.Parent = botHalf

            local vs = Instance.new("TextLabel")
            vs.Size = UDim2.new(1, 0, 1, 0); vs.BackgroundTransparency = 1
            vs.Text = "VS"; vs.TextColor3 = Color3.fromRGB(255, 255, 255)
            vs.Font = Enum.Font.GothamBlack; vs.TextSize = 80
            vs.TextStrokeTransparency = 0.3; vs.TextStrokeColor3 = Color3.fromRGB(255, 80, 180)
            vs.ZIndex = F.silZ(192); vs.Parent = sg

            task.wait(0.8)
            TweenService:Create(topHalf, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
                Position = UDim2.new(0, 0, -0.5, 0)
            }):Play()
            TweenService:Create(botHalf, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
                Position = UDim2.new(0, 0, 1, 0)
            }):Play()
            TweenService:Create(vs, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
            task.wait(0.6); sg:Destroy()
        end)
    end
end

-- ============================================================
--  MATCH SEARCH — find other players running this injector
-- ============================================================
local SCRIPT_TAG_ATTR     = "FNFInjectorLoaded"
local SCRIPT_VERSION_ATTR = "FNFInjectorVersion"
local MATCH_REMOTE_NAME   = "FNFMatchRemote"

local matchRemote = nil
local matchResultsCb = nil

function F.setupMatchRemote()
    local ok, remote = pcall(function()
        return ReplicatedStorage:WaitForChild(MATCH_REMOTE_NAME, 6)
    end)
    if ok and remote then
        matchRemote = remote
        F.own(matchRemote.OnClientEvent:Connect(function(kind, payload)
            if kind == "list" and matchResultsCb then
                matchResultsCb(payload)
            end
        end))
    end
    return matchRemote ~= nil
end

function F.broadcastScriptPresence()
    pcall(function()
        LocalPlayer:SetAttribute(SCRIPT_TAG_ATTR, true)
        LocalPlayer:SetAttribute(SCRIPT_VERSION_ATTR, INJECTOR_VERSION)
    end)
    if matchRemote then
        matchRemote:FireServer("announce", INJECTOR_VERSION)
    end
end

function F.searchForMatches(query, onResults)
    matchResultsCb = onResults
    if matchRemote then
        matchRemote:FireServer("list", query or "")
        return true
    end

    local out = {}
    local q = (query or ""):lower()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr:GetAttribute(SCRIPT_TAG_ATTR) then
            if q == "" or plr.Name:lower():find(q, 1, true) then
                table.insert(out, { Name = plr.Name })
            end
        end
    end
    if onResults then onResults(out) end
    return false
end

-- ============================================================
--  ANIMATOR HELPERS
-- ============================================================
function F.getAnimator(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return nil end
    local a = hum:FindFirstChildOfClass("Animator")
    if not a then a = Instance.new("Animator"); a.Parent = hum end
    return a
end

-- Tracks are cached per animation, not per key, so cycling between several
-- animations on one note never destroys and reloads anything.
function F.getTrack(assetId, looped)
    if not animator or not assetId or assetId == "" then return nil end
    if Pose.owner ~= animator then
        Pose.cache = {}           -- new character, new Animator: old tracks are dead
        Pose.owner = animator
    end
    local ck = assetId .. (looped and ":L" or ":O")
    local t = Pose.cache[ck]
    if t then return t end
    local ok, res = pcall(function()
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://" .. assetId
        local tr = animator:LoadAnimation(anim)
        tr.Priority = PRIORITY
        tr.Looped = looped and true or false
        return tr
    end)
    if ok and res then Pose.cache[ck] = res; return res end
    warn("[FNF] Load fail: " .. tostring(assetId))
    return nil
end

function F.playDodge()
    if Pose.dodgeId == "" or not animator then return end
    local t = F.getTrack(Pose.dodgeId, false)
    if not t then return end
    t.Priority = Enum.AnimationPriority.Action2   -- plays over a held pose
    if Hold.track then Hold.clear(false) end
    t:Play(0.05)
    t:AdjustSpeed(Pose.dodgeSpeed)
end

-- Load and download every bind's animations ahead of time, so the very
-- first press of each one is as fast as the hundredth.
function F.preloadBinds()
    if not animator then return end
    local anims = {}
    local function add(id, looped)
        if id and id ~= "" then
            local t = F.getTrack(id, looped)
            if t and t.Animation then table.insert(anims, t.Animation) end
        end
    end
    for _, row in ipairs(CurrentBindings) do
        add(row.id, row.holdLoop)
        for _, a in ipairs(row.alts or {}) do add(a.id, row.holdLoop) end
    end
    add(Pose.dodgeId, false)
    task.spawn(function()
        pcall(function() game:GetService("ContentProvider"):PreloadAsync(anims) end)
    end)
end

-- Tracks now live in a shared cache, so a key releasing its slot only
-- stops the track; destroying it would break every other key using it.
function F.destroyTrack(key)
    local t = animTracks[key]
    if t then pcall(function() t:Stop(0) end) animTracks[key] = nil end
end

function F.destroyIdleTrack()
    if idleTrack then pcall(function() idleTrack:Stop(0) end) pcall(function() idleTrack:Destroy() end) idleTrack = nil end
    idleLooping = false
end

function F.destroySeqTrack()
    if seqTrack then pcall(function() seqTrack:Stop(0) end) pcall(function() seqTrack:Destroy() end) seqTrack = nil end
end

function F.cleanupAll()
    Arms.reset()   -- the arm tracks belonged to the animator that's going away
    idleLooping = false; seqPlaying = false
    F.destroyIdleTrack(); F.destroySeqTrack()
    for k in pairs(animTracks) do F.destroyTrack(k) end
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    connections = {}; animator = nil; character = nil
    faceDecal = nil; defaultFaceId = nil
    -- cutter tracks belonged to the animator that just went away
    cutterTrack = nil
    Pose.cache = {}
    Pose.owner = nil
    Cut.tracks = {}
    Cut.trackOwner = nil
end

-- ============================================================
--  NOTIFICATION TOASTS
-- ============================================================
local notifyContainer = nil
F.notify = function(text, kind)
    if not F.alive then return end   -- unloaded: the toast list is gone
    if not notifyContainer then F.log("[toast] "..text); return end
    kind = kind or "info"
    local colors = {
        info    = Color3.fromRGB(80, 200, 255),
        success = Color3.fromRGB(80, 220, 140),
        warn    = Color3.fromRGB(255, 190, 80),
        error   = Color3.fromRGB(255, 90, 90),
    }
    local toast = Instance.new("Frame")
    toast.Size = UDim2.new(1, 0, 0, 38)
    toast.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    toast.BackgroundTransparency = 0.25
    toast.BorderSizePixel = 0
    toast.ClipsDescendants = true
    toast.Parent = notifyContainer
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0,12); corner.Parent = toast
    local stroke = Instance.new("UIStroke"); stroke.Color = colors[kind] or colors.info; stroke.Thickness = 1; stroke.Transparency = 0.4; stroke.Parent = toast

    local tGrad = Instance.new("UIGradient")
    tGrad.Color = ColorSequence.new(Color3.fromRGB(255,255,255), Color3.fromRGB(180,180,200))
    tGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.88),
        NumberSequenceKeypoint.new(0.4, 0.95),
        NumberSequenceKeypoint.new(1, 0.92),
    })
    tGrad.Rotation = 90; tGrad.Parent = toast

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 6, 0, 6); dot.Position = UDim2.new(0, 10, 0.5, -3)
    dot.BackgroundColor3 = colors[kind] or colors.info
    dot.BorderSizePixel = 0; dot.Parent = toast
    local dotCorner = Instance.new("UICorner"); dotCorner.CornerRadius = UDim.new(1,0); dotCorner.Parent = dot

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -28, 1, 0); lbl.Position = UDim2.new(0, 22, 0, 0)
    lbl.BackgroundTransparency = 1; lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(240,240,250); lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 11; lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextWrapped = true; lbl.Parent = toast

    toast.Position = UDim2.new(1, 20, 0, 0)
    TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new(0,0,0,0) }):Play()

    task.delay(2.6, function()
        if not toast or not toast.Parent then return end
        local t = TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Position = UDim2.new(1, 20, 0, 0), BackgroundTransparency = 1 })
        TweenService:Create(lbl, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.25), { Transparency = 1 }):Play()
        TweenService:Create(dot, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
        t:Play()
        t.Completed:Connect(function() if toast then toast:Destroy() end end)
    end)
end

-- ============================================================
--  THEME SYSTEM
-- ============================================================
function F.regStroke(obj) table.insert(themedStrokes, obj); obj.Color = THEMES[currentThemeName].accent end
function F.regBg(obj)     table.insert(themedBgs, obj);     obj.BackgroundColor3 = THEMES[currentThemeName].accent end
function F.regText(obj)   table.insert(themedTexts, obj);   obj.TextColor3 = THEMES[currentThemeName].accent end

-- Recolour one themed list, dropping anything that's been destroyed. The
-- panel is rebuilt on every load / import and its old pieces used to stay
-- in these lists for good, so the RGB theme (which repaints 20 times a
-- second) got slower the longer you played.
function F.paintThemed(list, prop, accent)
    local n = 0
    for i = 1, #list do
        local o = list[i]
        if o.Parent ~= nil then
            n = n + 1
            list[n] = o
            o[prop] = accent
        end
    end
    for i = #list, n + 1, -1 do list[i] = nil end
end

function F.applyThemeColors(accent)
    F.accentNow = accent
    pcall(F.paintThemed, themedStrokes, "Color", accent)
    pcall(F.paintThemed, themedBgs, "BackgroundColor3", accent)
    pcall(F.paintThemed, themedTexts, "TextColor3", accent)
end

function F.setTheme(name)
    if not THEMES[name] then return end
    currentThemeName = name
    rgbCycleOn = (name == "RGB")
    if not rgbCycleOn then
        F.applyThemeColors(THEMES[name].accent)
    end
    -- Mono goes hard black with white hairlines, like the stage overlay
    local mono = (name == "Mono")
    local gui = PlayerGui:FindFirstChild("FNFInjectorGui")
    local main = gui and gui:FindFirstChild("Main")
    if main then
        main.BackgroundColor3 = mono and Color3.new(0, 0, 0) or Color3.fromRGB(13, 12, 19)
        main.BackgroundTransparency = mono and 0.02 or 0.04
        for _, d in ipairs(main:GetDescendants()) do
            if d:IsA("UIGradient") and d.Parent == main then
                d.Enabled = not mono
            elseif d:IsA("UIStroke") then
                d.Thickness = mono and 1.6 or 1
            end
        end
    end
    F.notify("Theme set to "..name, "info")
end

task.spawn(function()
    local hue = 0
    while F.alive do
        task.wait(0.05)
        if rgbCycleOn then
            hue = (hue + 0.006) % 1
            F.applyThemeColors(Color3.fromHSV(hue, 0.85, 1))
        end
    end
end)

-- ============================================================
--  FACE SYSTEM
-- ============================================================
function F.initFace(char)
    local head = char:FindFirstChild("Head")
    if not head then return end
    local d = head:FindFirstChild("face")
    if not d or d.ClassName ~= "Decal" then return end
    faceDecal = d
    defaultFaceId = d.Texture
    F.log("Face found: "..defaultFaceId)
end

function F.swapFace(dir)
    if not faceDecal then return end
    local id = faceIds[dir]
    if id and id ~= "" then
        faceDecal.Texture = "rbxassetid://"..id
    end
end

function F.restoreFace()
    if faceDecal and defaultFaceId then
        faceDecal.Texture = defaultFaceId
    end
end

-- ============================================================
--  LEGS ON GROUND
-- ============================================================
function F.applyLegsLock(locked)
    if not character then return end
    local hum = character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if locked then
        -- only remember real values: locking twice (loading a save while
        -- already locked) used to save the zeros and leave you frozen
        if hum.WalkSpeed > 0 then savedWalkSpeed = hum.WalkSpeed end
        if hum.JumpPower > 0 then savedJumpPower = hum.JumpPower end
        if hum.JumpHeight > 0 then F.savedJumpHeight = hum.JumpHeight end
        hum.WalkSpeed = 0
        hum.JumpPower = 0
        hum.JumpHeight = 0   -- games that use JumpHeight ignore JumpPower
    else
        hum.WalkSpeed = savedWalkSpeed
        hum.JumpPower = savedJumpPower
        hum.JumpHeight = F.savedJumpHeight or 7.2
    end
end

-- ============================================================
--  RECENTS
-- ============================================================

function F.pushRecent(id, label)
    if not id or id == "" then return end
    for i = #recents, 1, -1 do
        if recents[i].id == id then table.remove(recents, i) end
    end
    table.insert(recents, 1, { id = id, label = label or id })
    while #recents > RECENTS_CAP do table.remove(recents) end
    if F.refreshRecentsUI then F.refreshRecentsUI() end
end

-- ============================================================
--  LIVE PREVIEW HELPERS
-- ============================================================
function F.updatePreviewAnimation(assetId, label)
    StatusState.currentAnimName = label or assetId
    StatusState.currentAnimId = assetId
    if F.refreshStatusUI then F.refreshStatusUI() end
    if not previewAnimator or not assetId or assetId == "" then return end
    local ok, result = pcall(function()
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://"..assetId
        local t = previewAnimator:LoadAnimation(anim)
        t.Priority = Enum.AnimationPriority.Action
        return t
    end)
    if ok and result then
        for _, t in ipairs(previewAnimator:GetPlayingAnimationTracks()) do t:Stop(0) end
        result.Looped = true    -- hold the pose instead of ending after one cycle
        result:Play(0.05)
    end
end

-- ============================================================
--  RP TUG-OF-WAR LOGIC
-- ============================================================
function F.stopWatchingTargetAnims()
    if targetAnimConn then targetAnimConn:Disconnect(); targetAnimConn = nil end
    if targetCharAddedConn then targetCharAddedConn:Disconnect(); targetCharAddedConn = nil end
end

function F.triggerRetreat()
    if not rpModeEnabled or not currentTarget then return end
    if not character or not currentTarget.Character then return end

    local myRoot = character:FindFirstChild("HumanoidRootPart")
    local targetRoot = currentTarget.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot or not targetRoot then return end

    local awayVector = (myRoot.Position - targetRoot.Position)
    local distance = awayVector.Magnitude
    if distance <= 0.001 then return end

    if distance < rpMaxDistance then
        local actualStep = math.min(rpRetreatStep, rpMaxDistance - distance)
        myRoot.CFrame = myRoot.CFrame + (awayVector.Unit * actualStep)
    end
end

function F.startWatchingTargetAnims()
    F.stopWatchingTargetAnims()
    if not currentTarget then return end

    local function bindAnimator(targetChar)
        if not targetChar then return end
        local hum = targetChar:WaitForChild("Humanoid", 5)
        if not hum then return end
        local anr = hum:WaitForChild("Animator", 5) or hum:FindFirstChildOfClass("Animator")
        if not anr then return end
        targetAnimConn = F.own(anr.AnimationPlayed:Connect(function(track)
            local pri = track.Priority
            if pri == Enum.AnimationPriority.Idle
                or pri == Enum.AnimationPriority.Core
                or pri == Enum.AnimationPriority.Movement then
                return
            end
            if Split.enabled and track.Animation then
                Split.play("OPPONENT", (track.Animation.AnimationId or ""):match("%d+") or "")
            end
            FNFCamera:RegisterHit("OPPONENT")
            F.fightOpponentHit()
            if rpModeEnabled then F.triggerRetreat() end
        end))
    end

    if currentTarget.Character then bindAnimator(currentTarget.Character) end
    targetCharAddedConn = F.own(currentTarget.CharacterAdded:Connect(function(newChar)
        F.stopWatchingTargetAnims()
        bindAnimator(newChar)
    end))
end

function F.setTargetPlayer(partialName)
    if not partialName or partialName == "" then
        currentTarget = nil
        F.stopWatchingTargetAnims()
        F.notify("RP Target cleared.", "info")
        return nil
    end

    local lowerName = partialName:lower()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Name:lower():sub(1, #lowerName) == lowerName then
            currentTarget = player
            F.startWatchingTargetAnims()
            F.notify("Target locked: " .. player.Name, "success")
            return player
        end
    end
    F.notify("Player not found.", "warn")
    return nil
end

function F.triggerRPMovement()
    if not rpModeEnabled or not currentTarget then return end
    if not character or not currentTarget.Character then return end

    local myRoot = character:FindFirstChild("HumanoidRootPart")
    local targetRoot = currentTarget.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot or not targetRoot then return end

    local direction = (targetRoot.Position - myRoot.Position)
    local distance = direction.Magnitude
    if distance > rpMinDistance then
        local actualStep = math.min(rpMoveStep, distance - rpMinDistance)
        myRoot.CFrame = myRoot.CFrame + (direction.Unit * actualStep)
    end
end

-- ============================================================
--  PICK OPPONENT (wires RP + spacing + camera in one call)
-- ============================================================
function F.pickOpponent(player)
    if not player then return end
    F.setTargetPlayer(player.Name)
    if spacing then spacing:SetOpponent(player.Character) end
    FNFCamera:SetOpponentCharacter(player.Character)

    local function rebindOnRespawn(newChar)
        if spacing then spacing:SetOpponent(newChar) end
        FNFCamera:SetOpponentCharacter(newChar)
    end
    F.own(player.CharacterAdded:Connect(rebindOnRespawn))
    if Split.enabled then Split.refreshClones() end
end

-- ============================================================
--  COPY — do what another player does
--  Roblox already sends every player's animations to everyone, so
--  their Animator on your client says what they're playing, on
--  which frame and how fast. COPY MOVES plays the same on yours,
--  kept on the same frame, and Roblox sends yours on to everyone
--  else: the whole server sees you copying them. Nothing of theirs
--  is touched. Or put any animation they play into one of your
--  directions (BINDS, or the cutter) and pose with it yourself.
-- ============================================================
function Copy.idOf(track)
    local ok, id = pcall(function() return track.Animation.AnimationId end)
    return ok and type(id) == "string" and id:match("%d+") or nil
end

-- walk, run, idle, jump, fall: Roblox's own movement layer
function Copy.isMove(track)
    local p = track.Priority
    return p == Enum.AnimationPriority.Idle or p == Enum.AnimationPriority.Core
        or p == Enum.AnimationPriority.Movement
end

function Copy.myTrack(id)
    if not animator then return nil end
    if Copy.tracksFor ~= animator then Copy.tracks, Copy.tracksFor = {}, animator end
    local tr = Copy.tracks[id]
    if tr then return tr end
    local ok, t = pcall(function()
        local a = Instance.new("Animation")
        a.AnimationId = "rbxassetid://" .. id
        return animator:LoadAnimation(a)
    end)
    if not ok or not t then return nil end
    Copy.tracks[id] = t
    return t
end

function Copy.redraw()
    if Copy.redrawQueued or not Copy.refresh then return end
    Copy.redrawQueued = true
    task.delay(0.1, function()
        Copy.redrawQueued = false
        if Copy.refresh then pcall(Copy.refresh) end
    end)
end

function Copy.markBad(id)
    for _, e in ipairs(Copy.seen) do
        if e.id == id then e.bad = true end
    end
    Copy.redraw()
end

-- the name it has in the catalog, looked up once per animation
function Copy.lookupName(id)
    if Copy.names[id] ~= nil then return end
    Copy.names[id] = false
    task.spawn(function()
        local ok, info = pcall(function()
            return game:GetService("MarketplaceService"):GetProductInfo(tonumber(id), Enum.InfoType.Asset)
        end)
        if ok and type(info) == "table" and type(info.Name) == "string" and info.Name ~= "" then
            Copy.names[id] = info.Name
            Copy.redraw()
        end
    end)
end

function Copy.nameOf(e)
    return Copy.names[e.id] or (e.name ~= "" and e.name) or ("animation " .. e.id)
end

-- their track starts: start yours
function Copy.mirror(theirs)
    if not Copy.on or Copy.links[theirs] then return end
    local move = Copy.isMove(theirs)
    if move and not Copy.walkToo then return end
    local id = Copy.idOf(theirs)
    local mine = id and Copy.myTrack(id)
    if not mine then return end
    local ok = pcall(function()
        -- their walk and idle sit on Roblox's movement layer, under your own
        -- walk and idle; copied, they go up to the action layer so they show
        mine.Priority = move and Enum.AnimationPriority.Action or theirs.Priority
        mine.Looped = theirs.Looped
        mine:Play(0.1, math.max(theirs.WeightTarget, 0.05), theirs.Speed * Copy.speed)
        if Copy.sync then mine.TimePosition = theirs.TimePosition end
    end)
    if not ok then return end
    Copy.links[theirs] = mine
    -- an animation this game won't let you play never gets a length
    task.delay(1.5, function()
        local okL, len = pcall(function() return mine.Length end)
        if okL and len <= 0 then Copy.markBad(id) end
    end)
end

-- 20 times a second: stop what they stopped, follow speed, weight, frame
function Copy.syncStep()
    local sameFrame = Copy.sync and math.abs(Copy.speed - 1) < 0.01
    for theirs, mine in pairs(Copy.links) do
        local okP, playing = pcall(function() return theirs.IsPlaying end)
        if not okP or not playing then
            pcall(function() mine:Stop(0.15) end)
            Copy.links[theirs] = nil
        else
            pcall(function()
                local sp = theirs.Speed * Copy.speed
                local w = math.max(theirs.WeightTarget, 0.05)
                if not mine.IsPlaying then mine:Play(0.1, w, sp) end
                if math.abs(mine.Speed - sp) > 0.01 then mine:AdjustSpeed(sp) end
                if math.abs(mine.WeightTarget - w) > 0.02 then mine:AdjustWeight(w, 0.1) end
                if sameFrame and mine.Length > 0 and theirs.Length > 0
                    and math.abs(mine.TimePosition - theirs.TimePosition) > 0.12 then
                    mine.TimePosition = theirs.TimePosition
                end
            end)
        end
    end
end

function Copy.ensureSync()
    if Copy.syncConn then return end
    local acc = 0
    Copy.syncConn = F.own(RunService.Heartbeat:Connect(function(dt)
        acc = acc + dt
        if acc < 0.05 then return end
        acc = 0
        if next(Copy.links) then Copy.syncStep() end
    end))
end

function Copy.dropLinks()
    for theirs, mine in pairs(Copy.links) do
        pcall(function() mine:Stop(0.15) end)
        Copy.links[theirs] = nil
    end
end

-- start copying whatever they're in the middle of
function Copy.remirror()
    Copy.dropLinks()
    local anr = Copy.animr
    if not (Copy.on and anr and anr.Parent) then return end
    local ok, list = pcall(function() return anr:GetPlayingAnimationTracks() end)
    if ok then
        for _, tr in ipairs(list) do Copy.mirror(tr) end
    end
end

-- Puts one of their animations into one of your directions.
function Copy.assign(id, dir)
    if Copy.into == "CUTTER" then
        local s = cutterSlices[dir]
        if not s then return end
        s.id = id
        s.start = 0
        local len = 0
        for _, e in ipairs(Copy.seen) do
            if e.id == id then len = e.length end
        end
        if len > 0 then s.stop = len end
        pcall(F.cutterTrackFor, id)
        if Cut.idBoxes[dir] then Cut.idBoxes[dir].Text = id end
        pcall(Cut.drawSlices)
        F.notify(dir .. " (cutter) now plays " .. id .. (cutterEnabled and "" or " — turn the cutter ON to use it"), "success")
    else
        local row = F.rowForDir(dir)
        if not row then return end
        row.id = id
        F.destroyTrack(row.key)
        pcall(F.getTrack, id, row.holdLoop)
        if row.idBox then row.idBox.Text = id end
        F.notify(dir .. " now plays " .. id, "success")
    end
end

-- plays it once on you, to see what it is
function Copy.try(id)
    local tr = Copy.myTrack(id)
    if not tr then return end
    pcall(function()
        tr.Priority = PRIORITY
        tr.Looped = false
        tr:Play(0.1)
    end)
end

function Copy.log(id, track)
    local e
    for i, s in ipairs(Copy.seen) do
        if s.id == id then e = table.remove(Copy.seen, i); break end
    end
    if not e then
        local nm = ""
        pcall(function() nm = track.Animation.Name end)
        if nm == "Animation" then nm = "" end
        e = { id = id, name = nm, length = 0, count = 0, bad = false }
        Copy.lookupName(id)
    end
    e.count = e.count + 1
    pcall(function() if track.Length > 0 then e.length = track.Length end end)
    table.insert(Copy.seen, 1, e)
    while #Copy.seen > 30 do table.remove(Copy.seen) end

    -- FILL: their next different poses go into the waiting directions
    if Copy.fill and #Copy.fill > 0 and not Copy.fillUsed[id] then
        Copy.fillUsed[id] = true
        Copy.assign(id, table.remove(Copy.fill, 1))
        if #Copy.fill == 0 then
            Copy.fill = nil
            F.notify("All four directions filled from their poses", "success")
        end
    end
    -- the length shows up once the animation has loaded
    if e.length <= 0 then
        task.delay(1, function()
            pcall(function()
                if track.Length > 0 then e.length = track.Length; Copy.redraw() end
            end)
        end)
    end
    Copy.redraw()
end

function Copy.onPlayed(track)
    local id = Copy.idOf(track)
    if not id then return end
    if not Copy.isMove(track) then Copy.log(id, track) end
    Copy.mirror(track)
end

function Copy.bindChar(plr, char)
    task.spawn(function()
        local hum = char and char:WaitForChild("Humanoid", 8)
        local anr = hum and (hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 5))
        if not anr or Copy.target ~= plr then return end
        if Copy.conn then Copy.conn:Disconnect() end
        Copy.animr = anr
        Copy.conn = F.own(anr.AnimationPlayed:Connect(function(tr) Copy.onPlayed(tr) end))
        local ok, list = pcall(function() return anr:GetPlayingAnimationTracks() end)
        if ok then
            for _, tr in ipairs(list) do Copy.onPlayed(tr) end
        end
    end)
end

function Copy.unbind()
    for _, k in ipairs({ "conn", "charConn", "leaveConn" }) do
        if Copy[k] then
            pcall(function() Copy[k]:Disconnect() end)
            Copy[k] = nil
        end
    end
    Copy.dropLinks()
    Copy.animr = nil
end

function Copy.setTarget(plr)
    Copy.unbind()
    Copy.target = plr
    Copy.seen, Copy.fill, Copy.fillUsed = {}, nil, {}
    if plr then
        if plr.Character then Copy.bindChar(plr, plr.Character) end
        Copy.charConn = F.own(plr.CharacterAdded:Connect(function(c)
            Copy.dropLinks()
            Copy.bindChar(plr, c)
        end))
        Copy.leaveConn = F.own(Players.PlayerRemoving:Connect(function(p)
            if p == Copy.target then
                F.notify(p.DisplayName .. " left — stopped copying", "info")
                Copy.setTarget(nil)
            end
        end))
        Copy.ensureSync()
    else
        Copy.on = false
    end
    Copy.redraw()
end

function Copy.setOn(on)
    if on and not Copy.target then
        F.notify("Pick a player to copy first", "warn")
        on = false
    end
    Copy.on = on
    if on then
        Copy.ensureSync()
        Copy.remirror()
        F.notify("Copying " .. Copy.target.DisplayName, "success")
    else
        Copy.dropLinks()
    end
    Copy.redraw()
end

-- ============================================================
--  PROXIMITY BLOCK — invisible wall between you and opponent
-- ============================================================
F.startProximityBlock = function()
    if proximityBlockConn then proximityBlockConn:Disconnect(); proximityBlockConn = nil end
    proximityBlockConn = F.own(RunService.Heartbeat:Connect(function()
        if not proximityBlockEnabled or not currentTarget then return end
        if not character or not currentTarget.Character then return end
        local myRoot = character:FindFirstChild("HumanoidRootPart")
        local oppRoot = currentTarget.Character:FindFirstChild("HumanoidRootPart")
        if not myRoot or not oppRoot then return end

        local diff = myRoot.Position - oppRoot.Position
        local flatDiff = Vector3.new(diff.X, 0, diff.Z)
        local dist = flatDiff.Magnitude
        if dist < proximityBlockDist and dist > 0.001 then
            local pushOut = (proximityBlockDist - dist)
            myRoot.CFrame = myRoot.CFrame + (flatDiff.Unit * pushOut)
        end
    end))
end

function F.stopProximityBlock()
    if proximityBlockConn then proximityBlockConn:Disconnect(); proximityBlockConn = nil end
end

-- ============================================================
--  FIGHTING SYSTEM — momentum pushback + double notes
-- ============================================================
local FS = fightState

function F.getFightRoots()
    if not character or not currentTarget or not currentTarget.Character then return nil, nil end
    return character:FindFirstChild("HumanoidRootPart"),
           currentTarget.Character:FindFirstChild("HumanoidRootPart")
end

function F.fightPush(whoRoot, awayFromRoot, studs)
    if not whoRoot or not awayFromRoot then return end
    local diff = whoRoot.Position - awayFromRoot.Position
    local flat = Vector3.new(diff.X, 0, diff.Z)
    if flat.Magnitude < 0.001 then flat = Vector3.new(0, 0, 1) end
    local push = math.min(studs, FS.momentumCap)
    whoRoot.CFrame = whoRoot.CFrame + (flat.Unit * push)
end

F.deactivateFight = function()
    if not FS.active then return end
    FS.active = false
    FS.playerMomentum = 0
    FS.opponentMomentum = 0
    if F.refreshFightUI then F.refreshFightUI() end
end

function F.activateFight()
    if FS.active then return end
    FS.active = true
    if F.refreshFightUI then F.refreshFightUI() end
end

F.startFightLoop = function()
    if fightShakeConn then fightShakeConn:Disconnect() end
    fightShakeConn = F.own(RunService.Heartbeat:Connect(function(dt)
        if not fightModeEnabled or not FS.active then return end
        local now = os.clock()

        FS.playerMomentum = FS.playerMomentum * FS.momentumDecay
        FS.opponentMomentum = FS.opponentMomentum * FS.momentumDecay
        if FS.playerMomentum < 0.01 then FS.playerMomentum = 0 end
        if FS.opponentMomentum < 0.01 then FS.opponentMomentum = 0 end

        local lastAny = math.max(FS.lastPlayerHit, FS.lastOpponentHit)
        if now - lastAny > FS.idleTimeout then
            F.deactivateFight()
            return
        end

        local totalMomentum = FS.playerMomentum + FS.opponentMomentum
        local fightIntensity = math.clamp(totalMomentum / (FS.momentumCap * 0.6), 0, 1)
        if fightIntensity > FNFCamera.targetIntensity then
            FNFCamera.targetIntensity = fightIntensity
        end

        for i = #FS.playerHitTimes, 1, -1 do
            if now - FS.playerHitTimes[i] > FS.streakWindow then table.remove(FS.playerHitTimes, i) end
        end
        for i = #FS.opponentHitTimes, 1, -1 do
            if now - FS.opponentHitTimes[i] > FS.streakWindow then table.remove(FS.opponentHitTimes, i) end
        end

        if F.refreshFightUI then F.refreshFightUI() end
    end))
end

F.fightPlayerHit = function(dir)
    if not fightModeEnabled or not currentTarget then return end
    local now = os.clock()

    if not FS.active then F.activateFight() end

    FS.lastPlayerHit = now
    table.insert(FS.playerHitTimes, now)

    local isDouble = false
    if now - FS.lastPlayerKeyTime < FS.doubleNoteWindow and #FS.lastPlayerKeys > 0 then
        local prevDir = FS.lastPlayerKeys[#FS.lastPlayerKeys]
        if prevDir ~= dir then
            isDouble = true
        end
    end
    table.insert(FS.lastPlayerKeys, dir)
    FS.lastPlayerKeyTime = now
    while #FS.lastPlayerKeys > 4 do table.remove(FS.lastPlayerKeys, 1) end

    local streakCount = #FS.playerHitTimes
    local streakMult = 1 + math.min(streakCount, 10) * 0.15

    local pushAmount
    if isDouble then
        pushAmount = FS.pushPerDouble * streakMult
        FNFCamera:DoubleNoteZoom(1)
        F.notify("DOUBLE NOTE", "warn")
    else
        pushAmount = FS.pushPerHit * streakMult
    end

    FS.playerMomentum = math.min(FS.playerMomentum + pushAmount, FS.momentumCap)

    local myRoot, oppRoot = F.getFightRoots()
    F.fightPush(oppRoot, myRoot, pushAmount)
end

F.fightOpponentHit = function()
    if not fightModeEnabled or not currentTarget then return end
    local now = os.clock()

    if not FS.active then F.activateFight() end

    FS.lastOpponentHit = now
    table.insert(FS.opponentHitTimes, now)

    local streakCount = #FS.opponentHitTimes
    local streakMult = 1 + math.min(streakCount, 10) * 0.15
    local pushAmount = FS.pushPerHit * streakMult

    FS.opponentMomentum = math.min(FS.opponentMomentum + pushAmount, FS.momentumCap)

    local myRoot, oppRoot = F.getFightRoots()
    F.fightPush(myRoot, oppRoot, pushAmount)
end

-- ============================================================
--  DIRECTIONAL ANIMATION PLAYBACK
-- ============================================================
function F.playAnim(key, assetId, speedMult, holdLoop)
    if not animator then return end
    speedMult = speedMult or 1
    if speedMult <= 0 then speedMult = 0.01 end
    local wantLooped = holdLoop and true or false

    local track = F.getTrack(assetId, wantLooped)
    if not track then return end
    animTracks[key] = track

    if wantLooped then
        track:Play(BLEND_IN)
        track:AdjustSpeed(speedMult)
    else
        local reach = math.max(Pose.reach, 0.005) / speedMult
        -- stamp this press; a delayed freeze from an earlier press on the
        -- same key checks the stamp and leaves the new press alone
        F.animGen = F.animGen or {}
        F.animGen[key] = (F.animGen[key] or 0) + 1
        local gen = F.animGen[key]
        track:Play(BLEND_IN)
        -- snap: straight to the pose this frame, if the clip has loaded
        if Pose.snap and track.Length > 0 then
            track:AdjustSpeed(0)
            track.TimePosition = math.max(0, track.Length - 0.01)
        else
            track.TimePosition = 0
            track:AdjustSpeed(track.Length > 0 and (track.Length / reach) or 10)
        end
        task.delay(reach, function()
            if F.animGen[key] == gen and track and track.IsPlaying then
                track:AdjustSpeed(0)
                track.TimePosition = math.max(0, track.Length - 0.01)
            end
        end)
    end

    StatusState.currentAnimName = key
    StatusState.currentAnimId   = assetId
    StatusState.speedMult       = speedMult
    StatusState.playing         = true
    if F.refreshStatusUI then F.refreshStatusUI() end
    F.updatePreviewAnimation(assetId, key)
    Split.play("PLAYER", assetId)
    F.pushRecent(assetId, key)
end

function F.stopAnim(key)
    local t = animTracks[key]
    if t and t.IsPlaying then
        if Hold.qualifies(t) then
            -- don't stop it: playAnim already freezes it on the final frame,
            -- so it just stays posed until the hold runs out or is interrupted
            Hold.start(t, key)
            if F.refreshStatusUI then F.refreshStatusUI() end
            return
        end
        t:Stop(BLEND_OUT)
    end
    StatusState.playing = false
    if F.refreshStatusUI then F.refreshStatusUI() end
end

-- Builds the pool for a note: the main ID plus every filled-in extra.
function F.animPool(row)
    local pool = {}
    if row.id and row.id ~= "" then table.insert(pool, row.id) end
    for _, a in ipairs(row.alts or {}) do
        if a.id and a.id ~= "" then table.insert(pool, a.id) end
    end
    return pool
end

-- Picks the animation this press plays.
--   CYCLE    — goes through them in order, one per press
--   RANDOM   — any of them, evenly
--   WEIGHTED — each extra has a % chance; the leftover % plays the main ID
function F.rollBindingAnimId(row)
    local pool = F.animPool(row)
    if #pool == 0 then return row.id end
    if #pool == 1 then return pool[1] end

    local mode = row.mode or "CYCLE"
    if mode == "RANDOM" then
        return pool[math.random(1, #pool)]
    elseif mode == "WEIGHTED" then
        local roll = math.random() * 100
        local acc = 0
        for _, alt in ipairs(row.alts) do
            acc += (alt.chance or 0)
            if roll <= acc and alt.id ~= "" then return alt.id end
        end
        return row.id
    end
    -- CYCLE
    row.cycleIdx = ((row.cycleIdx or 0) % #pool) + 1
    return pool[row.cycleIdx]
end

-- ============================================================
--  EMOTE CUTTER PLAYBACK
-- ============================================================
-- The animation a note actually plays: its own ID, or the default.
function F.cutterSliceId(dir)
    local s = cutterSlices[dir]
    if s and type(s.id) == "string" and s.id ~= "" then return s.id end
    return cutterAnimId
end

-- One gameplay track per animation, cached, so jumping between notes that
-- use different animations never reloads anything mid-song.
function F.cutterTrackFor(id)
    if not animator or not id or id == "" then return nil end

    -- Resetting destroys the old Animator. Tracks loaded on it still exist as
    -- objects and accept Play() without error, they just never animate. So
    -- whenever the Animator changes, every cached track is thrown away.
    if Cut.trackOwner ~= animator then
        Cut.tracks = {}
        Cut.trackOwner = animator
        cutterTrack = nil
    end

    local t = Cut.tracks[id]
    if t then return t end
    local ok, res = pcall(function()
        local a = Instance.new("Animation")
        a.AnimationId = "rbxassetid://" .. id
        local tr = animator:LoadAnimation(a)
        tr.Priority = PRIORITY
        tr.Looped = true
        return tr
    end)
    if ok and res then Cut.tracks[id] = res; return res end
    return nil
end

function F.cutterLoadTrack()
    for _, dir in ipairs(ARROW_ORDER) do F.cutterTrackFor(F.cutterSliceId(dir)) end
    cutterTrack = F.cutterTrackFor(cutterAnimId) or cutterTrack
    return cutterTrack
end

-- Walk the slice back to its first frame, then hold it there.
-- Stepped by hand rather than with a negative speed, so the timing is
-- exact and it can't overshoot past the start of the clip.
function F.cutterReverse(track, gen)
    if not track or not track.IsPlaying then return end
    local from = track.TimePosition
    local to = Cut.sliceStart
    local dur = math.max(Cut.returnTime, 0.01)
    track:AdjustSpeed(0)
    task.spawn(function()
        local t0 = os.clock()
        while gen == Cut.sliceGen and track.IsPlaying do
            local k = math.clamp((os.clock() - t0) / dur, 0, 1)
            k = k * k * (3 - 2 * k)            -- ease in and out
            track.TimePosition = from + (to - from) * k
            if k >= 1 then break end
            RunService.RenderStepped:Wait()
        end
        if gen ~= Cut.sliceGen or not track.IsPlaying then return end
        -- back at the original pose: pin it exactly on that frame
        track:AdjustSpeed(0)
        track.TimePosition = to
        if Cut.holdAfterReturn then
            -- Pose Hold decides how long (its timer, or until the next note).
            -- With Pose Hold off it simply stays here until you play again.
            if Hold.enabled and Hold.cutter then Hold.start(track, "slice") end
        else
            if Hold.track == track then Hold.detach() end
            track:Stop(BLEND_OUT)
        end
    end)
end

function F.cutterPlaySlice(dir)
    if not animator then return end
    local slice = cutterSlices[dir]
    if not slice then return end

    local id = F.cutterSliceId(dir)
    if not id or id == "" then return end
    local tr = F.cutterTrackFor(id)
    if not tr then return end

    -- moving to a slice from a DIFFERENT animation: retire the old track fast
    if cutterTrack and cutterTrack ~= tr and cutterTrack.IsPlaying then
        if Hold.track == cutterTrack then Hold.clear(false)
        else pcall(function() cutterTrack:Stop(0.05) end) end
    end
    -- same track: hand the held pose straight over, no gap back to idle
    if Hold.track then
        if Hold.track == tr then Hold.detach() else Hold.clear(false) end
    end
    cutterTrack = tr

    -- every press gets its own generation; any watcher from an earlier press
    -- sees the number change and quits, so it can't freeze THIS slice
    Cut.sliceGen = Cut.sliceGen + 1
    local gen = Cut.sliceGen

    local a, b = slice.start, slice.stop
    if b < a then a, b = b, a end
    local span = b - a
    Cut.sliceStart = math.max(0, a)

    -- already playing: don't call Play again, which restarts and hitches.
    -- Just move the playhead.
    if not cutterTrack.IsPlaying then cutterTrack:Play(0) end
    cutterTrack.TimePosition = math.max(0, a)

    if Cut.snap or span <= 0.001 then
        -- instant: land on the pose this frame
        cutterTrack:AdjustSpeed(0)
        cutterTrack.TimePosition = math.max(0, b)
        if Cut.reverse == "AUTO" then
            local track = cutterTrack
            task.delay(Cut.returnPause, function()
                if gen == Cut.sliceGen then F.cutterReverse(track, gen) end
            end)
        end
        return
    end

    -- speed the slice up so it always lands in `reach` seconds, whatever
    -- its real length, exactly like normal binds do
    cutterTrack:AdjustSpeed(span / math.max(Cut.reach, 0.01))

    local track = cutterTrack
    task.spawn(function()
        while gen == Cut.sliceGen and track and track.IsPlaying do
            local tp = track.TimePosition
            -- passed the stop, or the looped track wrapped back past the start
            if tp >= b or tp < a - 0.002 then
                track:AdjustSpeed(0)
                track.TimePosition = b
                break
            end
            RunService.RenderStepped:Wait()
        end
        -- AUTO: it landed, now take it home
        if Cut.reverse == "AUTO" and gen == Cut.sliceGen and track.IsPlaying then
            task.wait(Cut.returnPause)
            if gen == Cut.sliceGen then F.cutterReverse(track, gen) end
        end
    end)
end

function F.cutterStopSlice()
    if cutterTrack and cutterTrack.IsPlaying then
        -- AUTO is already on its way home; letting go changes nothing
        if Cut.reverse == "AUTO" then return end
        -- RELEASE: going back is what letting go means
        if Cut.reverse == "RELEASE" then
            Cut.sliceGen = Cut.sliceGen + 1       -- stop the forward watcher
            F.cutterReverse(cutterTrack, Cut.sliceGen)
            return
        end
        -- a slice is short by definition, so the cutter only checks the toggle
        if Hold.enabled and Hold.cutter then
            -- don't freeze mid-slice: the slice watcher carries it to its
            -- stop frame and freezes there, same as a normal pose reaching
            -- its final frame. We just stop it being cut off.
            Hold.start(cutterTrack, "slice")
            return
        end
        cutterTrack:Stop(BLEND_OUT)
    end
end

-- ============================================================
--  FNF SPRITES — loading
-- ============================================================
function Skin.resolveApi()
    if Skin.api then return end
    Skin.api = {
        asset  = findFn("getcustomasset", getcustomasset) or findFn("getsynasset", getsynasset),
        isfile = findFn("isfile", isfile),
        read   = findFn("readfile", readfile),
    }
end

-- Content id for one sprite, or nil when the file isn't in the folder.
-- Each file is turned into an asset once and remembered.
function Skin.img(name)
    local hit = Skin.cache[name]
    if hit ~= nil then return hit or nil end
    Skin.resolveApi()
    local path = Skin.folder .. "/" .. name .. ".png"
    local id = false
    if Skin.api.asset then
        local there = true
        if Skin.api.isfile then
            local ok, r = pcall(Skin.api.isfile, path)
            there = ok and r == true
        end
        if there then
            local ok, res = pcall(Skin.api.asset, path)
            if ok and type(res) == "string" and res ~= "" then id = res end
        end
    end
    Skin.cache[name] = id
    return id or nil
end

-- The strip is all-or-nothing: with any arrow piece missing it keeps its
-- drawn look rather than showing three sprites and a square.
function Skin.arrowsReady()
    if not Arrows.sprites then return false end
    if Skin.arrowsOk == nil then
        local ok = true
        for _, dir in ipairs(ARROW_ORDER) do
            for _, part in ipairs({ "strum_static_", "strum_confirm1_", "strum_confirm2_", "note_" }) do
                if not Skin.img(part .. dir) then ok = false end
            end
            for i = 1, 4 do Skin.img("splash_" .. dir .. "_" .. i) end   -- optional, but found now
        end
        Skin.arrowsOk = ok
        if ok then Skin.preload() end
    end
    return Skin.arrowsOk
end

-- Download everything found so far, so the first press of each arrow shows
-- its sprite straight away instead of a blank frame.
function Skin.preload()
    local list = {}
    for _, id in pairs(Skin.cache) do
        if id then list[#list + 1] = id end
    end
    task.spawn(function()
        pcall(function() game:GetService("ContentProvider"):PreloadAsync(list) end)
    end)
end

-- Forget what was found, so the next build looks in the folder again.
function Skin.reload()
    Skin.cache = {}
    Skin.arrowsOk = nil
end

-- side "P" is you: the game mirrors the player's icon so both look inward
function Skin.icon(name, side, losing)
    return Skin.img("icon_" .. name .. (losing and "_lose" or "") .. (side == "P" and "_flip" or ""))
end

-- The icon names the cutter found, for the "try one of these" toast.
function Skin.iconNames()
    Skin.resolveApi()
    if not Skin.api.read then return "" end
    local ok, text = pcall(Skin.api.read, Skin.folder .. "/icons.txt")
    return (ok and type(text) == "string") and text or ""
end

-- A JSON file from the workspace as a table, or nil.
function Skin.readJson(path)
    Skin.resolveApi()
    if not Skin.api.read then return nil end
    local ok, text = pcall(Skin.api.read, path)
    if not ok or type(text) ~= "string" or #text == 0 then return nil end
    local okJ, data = pcall(function() return HttpService:JSONDecode(text) end)
    return (okJ and type(data) == "table") and data or nil
end

-- ============================================================
--  STAGE — Boyfriend and Girlfriend
-- ============================================================
function Chars.load()
    if Chars.meta == nil then
        local meta = Skin.readJson(Skin.folder .. "/chars.json")
        local ok = meta and type(meta.bf) == "table" and type(meta.bf.anims) == "table"
        if ok then
            -- chars.json from the first version listed frames another way
            local idle = meta.bf.anims.idle
            ok = type(idle) == "table" and type(idle.f) == "table"
        end
        Chars.meta = ok and meta or false
    end
    return Chars.meta or nil
end

function Chars.info(id)
    local meta = Chars.load()
    local info = (meta and type(id) == "string") and meta[id] or nil
    return (type(info) == "table" and type(info.anims) == "table") and info or nil
end

function Chars.img(info, n)
    return Skin.img("chars/" .. tostring(info.dir) .. "/" .. string.format("%03d", n))
end

-- Who is opposite you: the song's opponent in solo mode, your pick otherwise.
function Chars.currentOpp()
    if Chars.info(Chars.freeOpp) then return Chars.freeOpp end
    return Chars.info("dad") and "dad" or nil
end

-- On when switched on, and during a song when solo mode shows them
-- (including its results card).
function Chars.wanted()
    return Chars.enabled
end

-- Build or remove the stage to match what is wanted. Returns false when it
-- is wanted but the frames are not in the sprites folder.
function Chars.refresh(rebuild)
    if Chars.wanted() then
        local oppNow = Chars.showOpp and Chars.currentOpp() or nil
        local built = (Chars.gui and Chars.gui.Parent) or (Chars.world and Chars.world.Parent)
        if rebuild or not built or oppNow ~= Chars.oppId then return Chars.build() end
        return true
    end
    Chars.teardownStage()
    return true
end

function Chars.teardownStage()
    if Chars.gui then Chars.gui:Destroy(); Chars.gui = nil end
    if Chars.world then Chars.world:Destroy(); Chars.world = nil end
    Chars.slots = nil
end

function Chars.newSlot(key, id)
    local info = Chars.info(id)
    if not info or not Chars.img(info, 0) then return nil end
    return { key = key, id = id, info = info, anim = nil, t = 0, untilT = 0, held = {}, left = false }
end

-- Everyone is shown at the same scale, so a tall character stays tall.
function Chars.screenSize(info)
    local k = 0.5 * Chars.scale / (info.gameScale or 0.5)
    return info.w * k, info.h * k
end

function Chars.worldSize(info)   -- in studs: BF comes out about avatar height
    local k = Chars.worldScale / (95 * (info.gameScale or 0.5))
    return info.w * k, info.h * k
end

function Chars.build()
    Chars.teardownStage()
    if not Chars.load() then return false end
    local slots = { bf = Chars.newSlot("bf", "bf"), gf = Chars.newSlot("gf", "gf") }
    if not (slots.bf and slots.gf) then return false end
    Chars.oppId = Chars.showOpp and Chars.currentOpp() or nil
    if Chars.oppId then slots.opp = Chars.newSlot("opp", Chars.oppId) end
    Chars.slots = slots
    if Chars.mode == "WORLD" then Chars.buildWorld() else Chars.buildScreen() end
    for _, s in pairs(slots) do Chars.dance(s, 0, true) end

    -- every frame downloaded up front, so no animation starts on a blank
    local list = {}
    for _, s in pairs(slots) do
        for n = 0, (s.info.frames or 0) - 1 do
            local id = Chars.img(s.info, n)
            if id then list[#list + 1] = id end
        end
    end
    task.spawn(function()
        pcall(function() game:GetService("ContentProvider"):PreloadAsync(list) end)
    end)

    if not Chars.conn then
        Chars.conn = F.own(RunService.RenderStepped:Connect(function() pcall(Chars.step) end))
    end
    return true
end

-- SCREEN: GF on her speaker with BF in front of her at the bottom right, the
-- opponent at the bottom left facing them. Both groups drag.
function Chars.buildScreen()
    local sg = F.own(Instance.new("ScreenGui"))
    sg.Name = "FNFStage"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true
    sg.DisplayOrder = F.silZ(58)   -- over the world, under the arrow strips
    sg.Parent = PlayerGui
    Chars.gui = sg
    local s = Chars.slots

    local function sprite(parent, w, h, side, z)
        local im = Instance.new("ImageLabel")
        im.BackgroundTransparency = 1
        im.AnchorPoint = Vector2.new(side, 1)
        im.Position = UDim2.new(side, 0, 1, 0)
        im.Size = UDim2.new(0, w, 0, h)
        im.ZIndex = z; im.Parent = parent
        return im
    end
    local gw, gh = Chars.screenSize(s.gf.info)
    local bw, bh = Chars.screenSize(s.bf.info)
    local right = Instance.new("Frame")
    right.Name = "Stage"; right.BackgroundTransparency = 1; right.Active = true
    right.AnchorPoint = Vector2.new(1, 1)
    right.Size = UDim2.new(0, gw * 0.62 + bw, 0, math.max(gh, bh))
    right.Position = UDim2.new(Chars.x, Chars.offX, Chars.y, Chars.offY)
    right.Parent = sg
    s.gf.label = sprite(right, gw, gh, 0, 1)
    s.bf.label = sprite(right, bw, bh, 1, 2)
    local groups = { { right, false } }

    if s.opp then
        local ow, oh = Chars.screenSize(s.opp.info)
        local left = Instance.new("Frame")
        left.Name = "Opponent"; left.BackgroundTransparency = 1; left.Active = true
        left.AnchorPoint = Vector2.new(0, 1)
        left.Size = UDim2.new(0, ow, 0, oh)
        left.Position = UDim2.new(Chars.oppX, Chars.oppOffX, Chars.oppY, Chars.oppOffY)
        left.Parent = sg
        s.opp.label = sprite(left, ow, oh, 0, 1)
        groups[2] = { left, true }
    end

    local drag = nil
    for _, g in ipairs(groups) do
        local h, isOpp = g[1], g[2]
        h.InputBegan:Connect(function(input)
            if not Chars.draggable then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                drag = { h = h, opp = isOpp, start = input.Position, pos = h.Position }
            end
        end)
    end
    for _, c in ipairs(Chars.dragConns or {}) do c:Disconnect() end
    Chars.dragConns = {
        F.own(UserInputService.InputChanged:Connect(function(input)
            if not drag then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch then
                local d = input.Position - drag.start
                local p = UDim2.new(drag.pos.X.Scale, drag.pos.X.Offset + d.X, drag.pos.Y.Scale, drag.pos.Y.Offset + d.Y)
                drag.h.Position = p
                if drag.opp then
                    Chars.oppX, Chars.oppOffX, Chars.oppY, Chars.oppOffY = p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset
                else
                    Chars.x, Chars.offX, Chars.y, Chars.offY = p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset
                end
            end
        end)),
        F.own(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                drag = nil
            end
        end)),
    }
end

-- WORLD: each character is a billboard on an invisible, anchored part in
-- the workspace. Made by your client, so only you see them, and they face
-- the camera from every side like paper cut-outs.
function Chars.buildWorld()
    local folder = F.own(Instance.new("Folder"))
    folder.Name = "FNFWorldStage"
    folder.Parent = Workspace
    Chars.world = folder
    for key, slot in pairs(Chars.slots) do
        local w, h = Chars.worldSize(slot.info)
        local part = Instance.new("Part")
        part.Name = key
        part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
        part.CastShadow = false
        part.Transparency = 1
        part.Size = Vector3.new(0.2, 0.2, 0.2)
        part.Parent = folder
        local bb = Instance.new("BillboardGui")
        bb.Size = UDim2.new(w, 0, h, 0)
        bb.StudsOffsetWorldSpace = Vector3.new(0, h / 2, 0)   -- feet on the ground
        bb.LightInfluence = 0
        bb.MaxDistance = 600
        bb.Adornee = part
        bb.Parent = part
        local im = Instance.new("ImageLabel")
        im.BackgroundTransparency = 1
        im.Size = UDim2.new(1, 0, 1, 0)
        im.Parent = bb
        slot.label, slot.part = im, part
    end
    Chars.placeWorld(Chars.anchor == nil)
end

-- where you stand, facing the way you face (kept level, so the stage stands upright)
function Chars.anchorFromMe()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local look = root.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude < 1e-3 then flat = Vector3.new(0, 0, -1) end
    return CFrame.lookAt(root.Position, root.Position + flat.Unit)
end

-- Stand everyone on whatever ground is under their spot.
function Chars.placeWorld(retake)
    if retake or not Chars.anchor then Chars.anchor = Chars.anchorFromMe() or Chars.anchor end
    local anchor = Chars.anchor
    if not (anchor and Chars.world and Chars.slots) then return end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { Chars.world, LocalPlayer.Character }
    for key, slot in pairs(Chars.slots) do
        local spot = Chars.WORLD_SPOTS[key]
        if spot and slot.part then
            local p = anchor:PointToWorldSpace(spot * Chars.worldScale)
            local hit = Workspace:Raycast(p + Vector3.new(0, 8, 0), Vector3.new(0, -60, 0), params)
            local y = hit and hit.Position.Y or (p.Y - 3)
            slot.part.CFrame = CFrame.new(p.X, y, p.Z)
        end
    end
end

function Chars.play(slot, anim)
    local a = slot.info.anims[anim]
    if not a then
        -- no miss pose for this character: the plain sing pose instead
        local plain = string.match(anim, "^(sing%u+)miss$")
        a = plain and slot.info.anims[plain]
        if not a then return false end
        anim = plain
    end
    slot.anim, slot.t = anim, os.clock()
    return true
end

-- how long one of their animations runs, in seconds
function Chars.length(slot, anim)
    local a = slot and anim and slot.info.anims[anim]
    return a and (#a.f / (a.fps or 24)) or 0
end

-- Put the right frame up. Looping animations cycle, the rest hold their
-- last frame, and an image is only touched when the frame changes.
function Chars.show(slot, now)
    if not (slot.label and slot.label.Parent and slot.anim) then return end
    local a = slot.info.anims[slot.anim]
    if not a or #a.f == 0 then return end
    local i = math.floor((now - slot.t) * (a.fps or 24))
    if a.loop then i = i % #a.f else i = math.min(i, #a.f - 1) end
    local n = a.f[i + 1]
    if slot.shown ~= n then
        slot.shown = n
        slot.label.Image = Chars.img(slot.info, n) or slot.label.Image
    end
end

-- Dance on the beat, each the way their own data says: GF (and anyone with
-- left / right dances) sways every beat, the rest bob every other beat.
function Chars.dance(slot, beat, force)
    local now = os.clock()
    if not force and (next(slot.held) ~= nil or now < slot.untilT) then return end
    local every = math.max(1, math.floor(slot.info.danceEvery or 1))
    if not force and beat % every ~= 0 then return end
    if slot.info.dance == "lr" then
        slot.left = not slot.left
        Chars.play(slot, slot.left and "danceLeft" or "danceRight")
    else
        Chars.play(slot, "idle")
    end
end

-- the beat they dance to: the song's in solo mode, the BPM setting otherwise
function Chars.beatNow()
    return math.floor(os.clock() * math.max(40, StatusState.bpm or 100) / 60)
end

function Chars.step()
    local slots = Chars.slots
    if not slots then return end
    local now = os.clock()
    local beat = Chars.beatNow()
    if beat ~= Chars.lastBeat then
        Chars.lastBeat = beat
        for _, s in pairs(slots) do Chars.dance(s, beat, false) end
    end
    for _, s in pairs(slots) do Chars.show(s, now) end
    -- WORLD with follow on: the stage keeps its place around you as you move.
    -- Without an anchor yet (your character wasn't loaded when it was built)
    -- it keeps trying to find you.
    if Chars.world and (Chars.follow or not Chars.anchor) and now >= (Chars.followAt or 0) then
        Chars.followAt = now + (Chars.follow and 0.1 or 0.5)
        Chars.placeWorld(true)
    end
end

function Chars.slot(who) return Chars.slots and Chars.slots[who or "bf"] end

-- who: "bf" (you, the default) or "opp"
function Chars.sing(dir, who)
    local s = Chars.slot(who)
    if not s then return end
    s.held[dir] = true
    -- a press that was just judged a miss keeps BF's miss pose
    if s.key == "bf" and os.clock() - (Chars.missAt or 0) < 0.05 then return end
    Chars.play(s, "sing" .. dir)
end

function Chars.release(dir, who)
    local s = Chars.slot(who)
    if not s then return end
    s.held[dir] = nil
    -- hold the pose before dancing again: a beat for BF, the character's own
    -- sing time for the opponent (up to two beats), like the game
    local bpm = StatusState.bpm or 100
    local beats = (s.key == "bf") and 1 or math.min(2, (s.info.singTime or 8) / 4)
    s.untilT = os.clock() + beats * 60 / math.max(40, bpm)
end

function Chars.miss(dir)
    Chars.missAt = os.clock()
    local s = Chars.slot("bf")
    if s and Chars.play(s, "sing" .. dir .. "miss") then
        s.untilT = os.clock() + math.min(0.6, Chars.length(s, s.anim))
    end
end

function Chars.gfReact(anim)
    local s = Chars.slot("gf")
    if not s then return end
    local name = (anim == "sad") and "drop70" or anim
    if anim == "cheer" and not s.info.anims.cheer then name = "combo50" end
    if Chars.play(s, name) then s.untilT = os.clock() + Chars.length(s, s.anim) end
end

function Chars.hey()
    local s = Chars.slot("bf")
    if s and Chars.play(s, "hey") then s.untilT = os.clock() + Chars.length(s, "hey") end
end

-- ============================================================
--  ARMS — point your arms, further the faster you pose
--  Every frame, after Roblox has applied your animations, the
--  shoulder joint of the reaching arm is turned toward the aim
--  (and the elbow straightened), blended over the animated pose.
-- ============================================================
-- How fast you're posing (presses over the last `window` seconds) and how
-- far that takes the arm, from calm to full.
function Arms.measure(now)
    local p = Arms.presses
    while #p > 0 and now - p[1] > Arms.window do table.remove(p, 1) end
    Arms.speed = #p / math.max(Arms.window, 0.1)
    local span = math.max(0.1, Arms.fastNps - Arms.slowNps)
    local k = math.clamp((Arms.speed - Arms.slowNps) / span, 0, 1)
    Arms.reachNow = Arms.calm + (Arms.full - Arms.calm) * k
    return Arms.reachNow
end

-- Your shoulder and elbow joints, R15 or R6, found again after a respawn.
function Arms.findJoints()
    if Arms.joints and Arms.jointsFor == character then return Arms.joints end
    Arms.joints = nil
    if not character then return nil end
    local function joint(...)
        for _, name in ipairs({ ... }) do
            local j = character:FindFirstChild(name, true)
            if j and j:IsA("Motor6D") then return j end
        end
        return nil
    end
    local r = { shoulder = joint("RightShoulder", "Right Shoulder"), elbow = joint("RightElbow") }
    local l = { shoulder = joint("LeftShoulder", "Left Shoulder"), elbow = joint("LeftElbow") }
    if not (r.shoulder and l.shoulder) then return nil end
    Arms.joints, Arms.jointsFor = { right = r, left = l }, character
    return Arms.joints
end

-- the turn that takes direction a onto direction b (both unit length)
function Arms.fromTo(a, b)
    local axis = a:Cross(b)
    local dot = math.clamp(a:Dot(b), -1, 1)
    if axis.Magnitude < 1e-5 then
        if dot > 0 then return CFrame.new() end
        local perp = (math.abs(a.X) < 0.9) and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)
        return CFrame.fromAxisAngle(a:Cross(perp).Unit, math.pi)
    end
    return CFrame.fromAxisAngle(axis.Unit, math.acos(dot))
end

-- Point one arm along world direction d, alpha of the way from its pose.
-- Part0 * C0 * Transform = Part1 * C1, so the arm's length (its part's -Y)
-- sits along C1's inverse of it in the joint's frame; turn that onto d.
function Arms.aim(j, d, alpha)
    local m = j.shoulder
    local p0 = m.Part0
    if not (p0 and m.Part1 and d.Magnitude > 1e-4) then return end
    local want = (p0.CFrame * m.C0):VectorToObjectSpace(d).Unit
    local rest = m.C1:VectorToObjectSpace(Vector3.new(0, -1, 0)).Unit
    m.Transform = m.Transform:Lerp(Arms.fromTo(rest, want), alpha)
    if j.elbow and Arms.straighten > 0 then
        j.elbow.Transform = j.elbow.Transform:Lerp(CFrame.new(), alpha * Arms.straighten)
    end
end

function Arms.step(dt)
    local now = os.clock()
    local dir = Arms.dir
    local preview = now < Arms.previewUntil
    local target = 0
    if Arms.enabled and dir and (Arms.active or preview) then
        local cfg = Arms.dirs[dir]
        target = math.clamp((preview and Arms.full or Arms.reachNow) * (cfg.max or 100) / 100, 0, 1)
    end
    local time = (target > Arms.alpha) and Arms.blendIn or Arms.fadeOut
    local stepBy = dt / math.max(time, 0.01)
    Arms.alpha = Arms.alpha + math.clamp(target - Arms.alpha, -stepBy, stepBy)
    if Arms.alpha < 0.002 or not dir then return end

    local joints = Arms.findJoints()
    local cam = Workspace.CurrentCamera
    if not (joints and cam) then return end
    -- the aim, built from what the camera sees: its right, toward it, and up
    local rv, lv = cam.CFrame.RightVector, cam.CFrame.LookVector
    local right = Vector3.new(rv.X, 0, rv.Z)
    local toward = Vector3.new(-lv.X, 0, -lv.Z)
    if right.Magnitude < 1e-3 or toward.Magnitude < 1e-3 then return end
    right, toward = right.Unit, toward.Unit
    local cfg = Arms.dirs[dir]
    local h, v = math.rad(cfg.h or 0), math.rad(cfg.v or 0)
    local side, fwd, up = math.cos(h) * math.cos(v), math.sin(h) * math.cos(v), math.sin(v)
    local upV = Vector3.new(0, 1, 0)

    -- which of your arms is on the right of the screen right now
    local rj, lj = joints.right, joints.left
    local torso = rj.shoulder.Part0
    local function screenX(j)
        local p = j.shoulder.Part1
        return (p and torso) and (p.Position - torso.Position):Dot(right) or 0
    end
    local onRight = (screenX(rj) >= screenX(lj)) and rj or lj
    local onLeft = (onRight == rj) and lj or rj

    local mode = cfg.arm or "AUTO"
    local a = Arms.alpha
    if mode == "BOTH" then
        -- both arms, mirrored: each reaches out to its own side
        Arms.aim(onRight, right * math.abs(side) + toward * fwd + upV * up, a)
        Arms.aim(onLeft, right * -math.abs(side) + toward * fwd + upV * up, a)
    else
        local arm
        if mode == "LEFT" then arm = lj
        elseif mode == "RIGHT" then arm = rj
        else arm = (side < -0.1) and onLeft or onRight end
        Arms.aim(arm, right * side + toward * fwd + upV * up, a)
    end
end

-- First person hides your whole body; while an arm is out, put the arms
-- back on screen so you can see them from your own view.
function Arms.showInFirstPerson()
    if not (Arms.firstPerson and Arms.alpha > 0.002 and character) then return end
    local head = character:FindFirstChild("Head")
    local cam = Workspace.CurrentCamera
    if not (head and cam) or (cam.CFrame.Position - head.Position).Magnitude > 1.5 then return end
    for _, name in ipairs({ "RightUpperArm", "RightLowerArm", "RightHand",
                            "LeftUpperArm", "LeftLowerArm", "LeftHand", "Right Arm", "Left Arm" }) do
        local p = character:FindFirstChild(name)
        if p and p:IsA("BasePart") then p.LocalTransparencyModifier = 0 end
    end
end

function Arms.start()
    if not Arms.conn then
        -- Stepped runs after the animations are applied, so the turn lands on top
        Arms.conn = F.own(RunService.Stepped:Connect(function(_, dt) pcall(Arms.step, dt) end))
    end
    if not Arms.viewBound then
        Arms.viewBound = true
        -- just after the camera, which is what hides your body in first person
        RunService:BindToRenderStep("FNFArmsView", Enum.RenderPriority.Camera.Value + 1, function()
            pcall(Arms.showInFirstPerson)
        end)
    end
end

-- ---- MIXED ANIMATIONS (everyone sees these) ---------------------------
-- A layer's track, loaded once per character and per way it's used (frozen
-- or playing through, mixed or over), so one use never changes another.
function Arms.mixTrack(slot)
    if Arms.mixOwner ~= animator then
        Arms.mixTracks, Arms.mixOwner, Arms.mixActive = {}, animator, {}
    end
    local frozen = (slot.at or -1) >= 0
    local key = slot.id .. (slot.over and ":over" or ":mix") .. (frozen and ":f" or ":p")
    local t = Arms.mixTracks[key]
    if t then return t end
    local ok, res = pcall(function()
        local a = Instance.new("Animation")
        a.AnimationId = "rbxassetid://" .. slot.id
        local tr = animator:LoadAnimation(a)
        -- the pose's own priority mixes with it; one above lays over it
        tr.Priority = slot.over and Enum.AnimationPriority.Action2 or PRIORITY
        if frozen then tr.Looped = false end
        return tr
    end)
    if ok and res then
        Arms.mixTracks[key] = res
        return res
    end
    warn("[FNF] mix layer didn't load: " .. tostring(slot.id))
    return nil
end

function Arms.isMix(track)
    for _, t in pairs(Arms.mixTracks) do
        if t == track then return true end
    end
    return false
end

-- The weight that gives a layer its share. Tracks of the same priority are
-- averaged by weight and the pose plays at weight 1, so a 75% share is
-- weight 3. An "over" layer's weight is its share as it is.
function Arms.layerWeight(slot, factor)
    local share = math.clamp((slot.share or 50) / 100 * factor, 0, 1)
    if slot.over then return math.max(share, 0.001) end
    if share >= 0.999 then return 1000 end
    return math.max(share / (1 - share), 0.001)
end

-- Take a track `frac` (0-1) of the way into its animation and hold it
-- there, landing in the same time a pose does.
function Arms.pinTrack(t, frac, gen)
    local function at() return math.max(0, t.Length - 0.02) * math.clamp(frac, 0, 1) end
    if t.Length <= 0 then
        -- not downloaded yet: let it play, and pin it once it has a length
        task.delay(math.max(Pose.reach, 0.1), function()
            if Arms.mixGen == gen and t.IsPlaying and t.Length > 0 then
                t:AdjustSpeed(0)
                t.TimePosition = at()
            end
        end)
        return
    end
    local target = at()
    if Pose.snap or target <= 0 then
        t:AdjustSpeed(0)
        t.TimePosition = target
        return
    end
    local land = math.max(Pose.reach, 0.005)
    t.TimePosition = 0
    t:AdjustSpeed(target / land)
    task.delay(land, function()
        if Arms.mixGen == gen and t.IsPlaying then
            t:AdjustSpeed(0)
            t.TimePosition = target
        end
    end)
end

function Arms.playLayer(slot, factor, gen)
    local t = Arms.mixTrack(slot)
    if not t then return nil end
    t:Play(0.06, Arms.layerWeight(slot, factor), 1)
    if (slot.at or -1) >= 0 then Arms.pinTrack(t, slot.at / 100, gen) end
    Arms.mixActive[#Arms.mixActive + 1] = t
    return t
end

function Arms.mixPress(dir)
    Arms.mixStop(0.08)
    if not (Arms.mixOn and animator) then return end
    local slots = Arms.mix[dir]
    if not slots then return end
    local gen = Arms.mixGen
    for _, slot in ipairs(slots) do
        if slot.id ~= "" then
            Arms.playLayer(slot, slot.speed and Arms.reachNow or 1, gen)
        end
    end
end

function Arms.mixStop(fade)
    Arms.mixGen = Arms.mixGen + 1
    for _, t in ipairs(Arms.mixActive) do
        if t.IsPlaying then pcall(function() t:Stop(fade or Arms.mixFade) end) end
    end
    Arms.mixActive = {}
end

-- TEST: one layer by itself, over whatever you're doing, for a moment
function Arms.testLayer(slot)
    if not animator or slot.id == "" then
        F.notify("Put an animation ID in that slot first", "warn")
        return
    end
    Arms.mixStop(0.08)
    local gen = Arms.mixGen
    if not Arms.playLayer(slot, 1, gen) then
        F.notify("That animation didn't load", "error")
        return
    end
    task.delay(1.5, function()
        if Arms.mixGen == gen and next(Arms.down) == nil then Arms.mixStop() end
    end)
end

-- ---- both halves follow the pose -----------------------------------------
function Arms.onPress(dir)
    local now = os.clock()
    Arms.down[dir] = true
    table.insert(Arms.presses, now)
    Arms.measure(now)
    Arms.mixPress(dir)
    Arms.dir = dir
    Arms.active = true
    Arms.start()
end

-- Both stay as long as the pose does: while a key is down, and while the
-- pose hold keeps a short pose up after you let go.
function Arms.onRelease(dir)
    Arms.down[dir] = nil
    if next(Arms.down) == nil and not Hold.track then Arms.relax() end
end

function Arms.relax()
    Arms.active = false
    Arms.mixStop()
end

-- a new character: find its joints again; its old tracks are dead
function Arms.reset()
    Arms.active, Arms.alpha, Arms.down = false, 0, {}
    Arms.joints, Arms.jointsFor = nil, nil
    Arms.mixTracks, Arms.mixOwner, Arms.mixActive = {}, nil, {}
    Arms.mixGen = Arms.mixGen + 1
end

-- TEST button: that note's arm, all the way out, for a moment
function Arms.test(dir)
    Arms.dir = dir
    Arms.previewUntil = os.clock() + 1.2
    Arms.start()
end

-- ============================================================
--  ARROW HUD REACTIONS
-- ============================================================
function F.hitArrow(dir)
    local f = arrowHudFrames[dir]
    if not f then return end
    f.down = true
    F.spawnNote(dir)
    F.spawnSplash(dir)
    F.bumpCombo(dir)
    if f.spr then
        -- the strum engine plays the game's own animation: confirm on a hit,
        -- and in a song the plain press when there was nothing to hit
        F.strumPlay(f, "confirm")
        return
    end
    TweenService:Create(f.bg, TweenInfo.new(0.05, Enum.EasingStyle.Linear), {
        BackgroundColor3 = ARROW_COLORS[dir].hit,
        Size = UDim2.new(0, Arrows.hitSize, 0, Arrows.hitSize),
    }):Play()
    if f.stroke then
        TweenService:Create(f.stroke, TweenInfo.new(0.05, Enum.EasingStyle.Linear), { Thickness = 4 }):Play()
    end
    if f.glow then
        f.glow.Visible = true
        TweenService:Create(f.glow, TweenInfo.new(0.05), { BackgroundTransparency = 0.35 }):Play()
    end
end

function F.releaseArrow(dir)
    local f = arrowHudFrames[dir]
    if not f then return end
    f.down = false
    if f.spr then
        -- back to rest, unless a hold is still running on this arrow (its own
        -- ending puts it back)
        if not f.holding then F.strumPlay(f, "static") end
        return
    end
    TweenService:Create(f.bg, TweenInfo.new(0.1, Enum.EasingStyle.Linear), {
        BackgroundColor3 = ARROW_COLORS[dir].idle,
        Size = UDim2.new(0, Arrows.size, 0, Arrows.size),
    }):Play()
    if f.stroke then
        TweenService:Create(f.stroke, TweenInfo.new(0.1, Enum.EasingStyle.Linear), { Thickness = 2 }):Play()
    end
    if f.glow then
        local tw = TweenService:Create(f.glow, TweenInfo.new(0.15), { BackgroundTransparency = 1 })
        tw:Play()
        tw.Completed:Connect(function() if f.glow then f.glow.Visible = false end end)
    end
end

-- ============================================================
--  IDLE ANIMATION
-- ============================================================
function F.idleSpeedFromBPM()
    if not BASE_BPM or BASE_BPM <= 0 then return 1 end
    return idleBPM / BASE_BPM
end

function F.loadIdleTrack(assetId, shouldLoop)
    F.destroyIdleTrack()
    if not animator then return nil end
    local ok, result = pcall(function()
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://"..assetId
        local t = animator:LoadAnimation(anim)
        t.Priority = Enum.AnimationPriority.Idle; t.Looped = shouldLoop
        return t
    end)
    if not ok then return nil end
    return result
end

function F.playIdleOnce(assetId, cb)
    local t = F.loadIdleTrack(assetId, false)
    if not t then return end
    idleTrack = t; t:Play(0.1)
    t:AdjustSpeed(F.idleSpeedFromBPM())
    F.updatePreviewAnimation(assetId, "IDLE (once)")
    t.Stopped:Connect(function() if cb then cb() end end)
end

function F.playIdleLoop(assetId)
    local t = F.loadIdleTrack(assetId, true)
    if not t then return end
    idleTrack = t; idleLooping = true; t:Play(0.1)
    t:AdjustSpeed(F.idleSpeedFromBPM())
    F.updatePreviewAnimation(assetId, "IDLE (loop)")
    StatusState.playing = true
    if F.refreshStatusUI then F.refreshStatusUI() end
end

function F.stopIdle()
    idleLooping = false
    if idleTrack and idleTrack.IsPlaying then idleTrack:Stop(0.2) end
    StatusState.playing = false
    if F.refreshStatusUI then F.refreshStatusUI() end
end

function F.setIdleBPM(bpm)
    if bpm and bpm > 0 then idleBPM = bpm end
    StatusState.bpm = idleBPM
    if idleTrack and idleTrack.IsPlaying then
        idleTrack:AdjustSpeed(F.idleSpeedFromBPM())
    end
    if F.refreshStatusUI then F.refreshStatusUI() end
end

function F.setIdleBaseBPM(bpm)
    if bpm and bpm > 0 then BASE_BPM = bpm end
    if idleTrack and idleTrack.IsPlaying then
        idleTrack:AdjustSpeed(F.idleSpeedFromBPM())
    end
end

-- ============================================================
--  LIBRARY — saved idles and cutter slots, in their own file
-- ============================================================
function Lib.path()
    return Save.useFolder and "FNFInjector/library.json" or "FNFInjector_library.json"
end

function Lib.cleanCut(s)
    if type(s) ~= "table" then return nil end
    local out = {
        name = type(s.name) == "string" and s.name:sub(1, 40) or "",
        id = type(s.id) == "string" and s.id:gsub("%D", "") or "",
        slices = {},
    }
    for _, k in ipairs(ARROW_ORDER) do
        local v = type(s.slices) == "table" and s.slices[k] or nil
        if type(v) ~= "table" then v = {} end
        out.slices[k] = {
            start = tonumber(v.start) or 0,
            stop = tonumber(v.stop) or 0,
            id = type(v.id) == "string" and v.id:gsub("%D", "") or "",
        }
    end
    return out
end

function Lib.load()
    local api = Save.api
    if not (api and api.read and api.isfile) then return end
    local ok, exists = pcall(api.isfile, Lib.path())
    if not ok or not exists then return end
    local ok2, txt = pcall(api.read, Lib.path())
    if not ok2 or type(txt) ~= "string" then return end
    local ok3, d = pcall(function() return HttpService:JSONDecode(txt) end)
    if not ok3 or type(d) ~= "table" then return end

    if type(d.idles) == "table" then
        Lib.idles = {}
        for _, e in ipairs(d.idles) do
            if type(e) == "table" and type(e.id) == "string" and e.id:match("^%d+$") then
                table.insert(Lib.idles, {
                    name = type(e.name) == "string" and e.name:sub(1, 40) or ("idle " .. e.id),
                    id = e.id,
                    bpm = tonumber(e.bpm) or 100,
                    base = tonumber(e.base) or 100,
                })
            end
        end
    end
    if type(d.cutter) == "table" then
        for i = 1, Lib.CUT_SLOTS do
            Lib.cutter[i] = Lib.cleanCut(d.cutter[tostring(i)])
        end
    end
end

function Lib.save()
    local api = Save.api
    if not (api and api.write) then
        if not Lib.warned then
            Lib.warned = true
            F.notify("Your executor can't write files — saved idles and cutter slots last until you leave", "warn")
        end
        return false
    end
    local cut = {}
    for i = 1, Lib.CUT_SLOTS do
        if Lib.cutter[i] then cut[tostring(i)] = Lib.cutter[i] end
    end
    local ok, json = pcall(function()
        return HttpService:JSONEncode({ version = 1, idles = Lib.idles, cutter = cut })
    end)
    if not ok then return false end
    local okW = pcall(api.write, Lib.path(), json)
    return okW
end

-- ============================================================
--  IDLE SAVING
--  The idle in the box and whether it was looping are part of your
--  save, so it starts again when you load and after you respawn.
--  SAVE IDLE keeps it (with its BPM) in your idle list for later.
-- ============================================================
function Idle.paintStatus(kind)
    local l = Idle.statusLbl
    if not l or not l.Parent then return end
    if kind == "LOOP" then
        l.Text = "● LOOPING"; l.TextColor3 = Color3.fromRGB(80,220,120)
    elseif kind == "ONCE" then
        l.Text = "▶ PLAYING"; l.TextColor3 = Color3.fromRGB(0,200,255)
    else
        l.Text = "● OFF"; l.TextColor3 = Color3.fromRGB(160,80,80)
    end
end

-- after you spawn: put the saved idle back on
function Idle.resume()
    if not (Idle.auto and Idle.id ~= "") then return end
    task.delay(0.5, function()
        if animator and Idle.auto and Idle.id ~= "" then
            F.playIdleLoop(Idle.id)
            Idle.paintStatus("LOOP")
        end
    end)
end

function Idle.saveCurrent(name, id)
    id = tostring(id or ""):gsub("%D", "")
    if id == "" then F.notify("Enter an idle anim ID first", "warn"); return end
    name = tostring(name or ""):gsub("[%c]", ""):sub(1, 40)
    name = name:match("^%s*(.-)%s*$")
    if name == "" then name = "idle " .. id end
    for i, e in ipairs(Lib.idles) do
        if e.id == id then table.remove(Lib.idles, i); break end
    end
    table.insert(Lib.idles, 1, { name = name, id = id, bpm = idleBPM, base = BASE_BPM })
    while #Lib.idles > 40 do table.remove(Lib.idles) end
    Lib.save()
    Idle.redraw()
    F.notify("Saved idle: " .. name, "success")
end

function Idle.use(e)
    Idle.id, Idle.auto = e.id, true
    if Idle.box then Idle.box.Text = e.id end
    if e.base and e.base > 0 then BASE_BPM = e.base end
    F.setIdleBPM(e.bpm or idleBPM)
    if Idle.syncBpmUI then Idle.syncBpmUI() end
    F.playIdleLoop(e.id)
    Idle.paintStatus("LOOP")
end

function Idle.redraw()
    local list = Idle.listFrame
    if not list or not list.Parent then return end
    for _, c in ipairs(list:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
    if #Lib.idles == 0 then
        F.makeLabel(list, "No saved idles yet — name one above and SAVE IDLE", UDim2.new(0,0,0,0),
            UDim2.new(1,-8,0,22), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 9)
        return
    end
    for i, e in ipairs(Lib.idles) do
        local rowF = Instance.new("Frame")
        rowF.Size = UDim2.new(1,-8,0,26); rowF.BackgroundTransparency = 1
        rowF.LayoutOrder = i; rowF.Parent = list
        local entry = e
        local b = F.makeBtn(rowF, string.format("%s  ·  %s  ·  %d BPM", e.name, e.id, math.floor((e.bpm or 0) + 0.5)),
            UDim2.new(0,0,0,0), UDim2.new(1,-36,1,0), Color3.fromRGB(30,28,44), nil, 9)
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.TextTruncate = Enum.TextTruncate.AtEnd
        b.MouseButton1Click:Connect(function()
            Idle.use(entry)
            F.notify("Idle: " .. entry.name, "info")
        end)
        local x = F.makeBtn(rowF, "✕", UDim2.new(1,-32,0,0), UDim2.new(0,32,1,0), Color3.fromRGB(120,40,40), nil, 10)
        x.MouseButton1Click:Connect(function()
            for j, s in ipairs(Lib.idles) do
                if s == entry then table.remove(Lib.idles, j); break end
            end
            Lib.save()
            Idle.redraw()
        end)
    end
end

-- ============================================================
--  ANIMATION BPM DETECTOR
-- ============================================================
function F.registerBpmTap()
    local now = os.clock()
    table.insert(bpmDetectTaps, now)
    while #bpmDetectTaps > BPM_TAP_WINDOW do table.remove(bpmDetectTaps, 1) end
    if #bpmDetectTaps < 3 then return nil end

    local gaps = {}
    for i = 2, #bpmDetectTaps do
        local gap = bpmDetectTaps[i] - bpmDetectTaps[i-1]
        if gap > 0.08 and gap < 3 then table.insert(gaps, gap) end
    end
    if #gaps == 0 then return nil end

    table.sort(gaps)
    local median = gaps[math.ceil(#gaps/2)]
    local sum, count = 0, 0
    for _, g in ipairs(gaps) do
        if g < median * 2 and g > median * 0.5 then sum = sum + g; count = count + 1 end
    end
    if count == 0 then return nil end
    local avgGap = sum / count
    detectedBPM = math.floor((60 / avgGap) + 0.5)
    return detectedBPM
end

function F.detectBpmFromIdleLength(beatsPerLoop)
    beatsPerLoop = beatsPerLoop or beatsPerIdleLoop
    if not idleTrack or not idleTrack.Length or idleTrack.Length <= 0 then return nil end
    local bpm = (beatsPerLoop * 60) / idleTrack.Length
    detectedBPM = math.floor(bpm + 0.5)
    return detectedBPM
end

-- ============================================================
--  SHARED MUSIC PLAYER (no VC)
-- ============================================================
function F.setupMusicRemote()
    local ok, remote = pcall(function()
        return ReplicatedStorage:WaitForChild("FNFMusicRemote", 8)
    end)
    if ok and remote then musicRemote = remote end
    return musicRemote ~= nil
end

function F.setMusicStatus(text, color)
    if musicStatusLbl then
        musicStatusLbl.Text = text
        if color then musicStatusLbl.TextColor3 = color end
    end
end

function F.watchMusicStatus(expectedId)
    task.spawn(function()
        local myTick = musicRequestTick
        local deadline = os.clock() + 8
        local snd = nil
        while os.clock() < deadline and myTick == musicRequestTick do
            snd = SoundService:FindFirstChild(MUSIC_SOUND_NAME)
            if snd and snd.SoundId:find(expectedId, 1, true) then break end
            task.wait(0.2)
        end
        if myTick ~= musicRequestTick then return end

        if not snd or not snd.SoundId:find(expectedId, 1, true) then
            F.setMusicStatus("✖ NO SERVER SCRIPT FOUND", Color3.fromRGB(255,80,80))
            return
        end

        local loadDeadline = os.clock() + 6
        while os.clock() < loadDeadline and myTick == musicRequestTick do
            if snd.IsLoaded then break end
            task.wait(0.15)
        end
        if myTick ~= musicRequestTick then return end

        if snd.IsLoaded and snd.IsPlaying then
            F.setMusicStatus("✔ PLAYING — allowed in this game", Color3.fromRGB(80,220,120))
        elseif snd.IsLoaded then
            F.setMusicStatus("● loaded, not playing", Color3.fromRGB(255,180,60))
        else
            F.setMusicStatus("✖ NOT PLAYABLE HERE (blocked/private asset)", Color3.fromRGB(255,80,80))
        end
    end)
end

function F.playMusicTrack(id)
    if not musicRemote then
        F.setMusicStatus("✖ NO SERVER SCRIPT FOUND", Color3.fromRGB(255,80,80))
        return
    end
    musicRequestTick = musicRequestTick + 1
    F.setMusicStatus("⏳ requesting...", Color3.fromRGB(0,200,255))
    musicRemote:FireServer("play", id)
    F.watchMusicStatus(id)
end

function F.stopMusicTrack()
    if not musicRemote then return end
    musicRequestTick = musicRequestTick + 1
    musicRemote:FireServer("stop")
    F.setMusicStatus("● stopped", Color3.fromRGB(160,80,80))
end

-- ============================================================
--  ANIMATION SEQUENCE MAKER
-- ============================================================
function F.playSequence()
    if seqPlaying or #sequence == 0 or not animator then return end
    seqPlaying = true
    task.spawn(function()
        for _, step in ipairs(sequence) do
            if not seqPlaying then break end
            if step.id and step.id ~= "" then
                F.destroySeqTrack()
                local ok, result = pcall(function()
                    local anim = Instance.new("Animation")
                    anim.AnimationId = "rbxassetid://"..step.id
                    local t = animator:LoadAnimation(anim)
                    t.Priority = PRIORITY; t.Looped = false
                    return t
                end)
                if ok then
                    seqTrack = result; seqTrack:Play(0)
                    F.updatePreviewAnimation(step.id, "SEQUENCE")
                end
            end
            task.wait(math.max(0.01, step.delay or 0.5))
        end
        F.destroySeqTrack()
        seqPlaying = false
    end)
end

function F.stopSequence()
    seqPlaying = false
    F.destroySeqTrack()
end

-- ============================================================
--  PLAYLIST MANAGER
-- ============================================================
function F.playPlaylist()
    if playlistPlaying or #playlist == 0 or not animator then return end
    playlistPlaying = true
    task.spawn(function()
        while playlistPlaying do
            local step = playlist[playlistIndex]
            if step and step.id and step.id ~= "" then
                F.destroySeqTrack()
                local ok, result = pcall(function()
                    local anim = Instance.new("Animation")
                    anim.AnimationId = "rbxassetid://"..step.id
                    local t = animator:LoadAnimation(anim)
                    t.Priority = PRIORITY; t.Looped = false
                    return t
                end)
                if ok then
                    seqTrack = result; seqTrack:Play(0)
                    F.updatePreviewAnimation(step.id, step.name or ("Playlist #"..playlistIndex))
                end
            end
            task.wait(math.max(0.05, (step and step.delay) or 1))
            if not playlistPlaying then break end
            playlistIndex = playlistIndex + 1
            if playlistIndex > #playlist then playlistIndex = 1 end
            if F.refreshPlaylistUI then F.refreshPlaylistUI() end
        end
        F.destroySeqTrack()
    end)
end

function F.stopPlaylist()
    playlistPlaying = false
    F.destroySeqTrack()
end

function F.nextPlaylistTrack()
    if #playlist == 0 then return end
    playlistIndex = playlistIndex + 1
    if playlistIndex > #playlist then playlistIndex = 1 end
    if F.refreshPlaylistUI then F.refreshPlaylistUI() end
end

function F.prevPlaylistTrack()
    if #playlist == 0 then return end
    playlistIndex = playlistIndex - 1
    if playlistIndex < 1 then playlistIndex = #playlist end
    if F.refreshPlaylistUI then F.refreshPlaylistUI() end
end

-- ============================================================
--  INPUT HANDLER
-- ============================================================
-- Rows whose key is physically down right now. A release only counts for
-- a row that's in here, and anything that takes the keyboard away (chat,
-- a TextBox, alt-tab) lets every one of them go.
F.heldRows = {}

function F.releaseHeldRows(keyName)
    for _, row in ipairs(CurrentBindings) do
        if F.heldRows[row] and (keyName == nil or row.key == keyName) then
            F.heldRows[row] = nil
            F.noteRelease(row)
        end
    end
end

function F.onInput(input, gameProcessed)
    local began = (input.UserInputState == Enum.UserInputState.Begin)
    local ended = (input.UserInputState == Enum.UserInputState.End)
    local kn = input.KeyCode and input.KeyCode.Name or "Unknown"

    -- Roblox already consumed this (chat bar, a TextBox, a CoreGui menu).
    -- Without this every keybind fires while you're typing. A note you were
    -- already holding still has to be let go, though: its key-up arrives
    -- "consumed" too, and ignoring it left the pose, the arrow and the hold
    -- streak stuck on until you pressed that key again.
    if gameProcessed or UserInputService:GetFocusedTextBox() then
        if ended then F.releaseHeldRows(kn) end
        return
    end

    if rebindingRow then
        if began and kn ~= "Unknown" and not kn:match("Mouse") then
            rebindingRow.key = kn
            rebindingRow.keyBtn.Text = kn
            rebindingRow.keyBtn.BackgroundColor3 = Color3.fromRGB(30, 20, 45)
            rebindingRow = nil
        end
        return
    end

    -- mouse buttons and touches carry no key, so nothing below can match
    if kn == "Unknown" then return end

    if began then
        -- Solo mode toggle keybind
        if kn == soloKey and FNFCamera.enabled then
            soloActive = not soloActive
            F.notify(soloActive and "🎤 SOLO MODE — spotlight on you!" or "Solo ended", soloActive and "success" or "info")
        end

        -- Silhouette mode toggle keybind
        if kn == silhouetteKey then Sil.set(not silhouetteActive) end

        -- Split screen toggle keybind
        if kn == Split.key then Split.setEnabled(not Split.enabled) end

        -- Health bar toggle keybind
        if kn == Health.key then Health.setEnabled(not Health.enabled) end

        -- Ride mode keybind
        if kn == Ride.key then Ride.setEnabled(not Ride.enabled) end

        -- Fly keybind
        if kn == Fly.key then Fly.toggle() end

        -- Boss battle cutscene keybind
        if kn == Boss.key then Boss.toggle() end

        -- Camera shots + cutscene
        if kn == Cam2.introKey then Cam2.play("INTRO")
        elseif kn == Cam2.outroKey then Cam2.play("OUTRO")
        elseif kn == Cutscene.key then Cutscene.toggle() end

        -- Win / lose
        if kn == Result.winKey then Result.win()
        elseif kn == Result.loseKey then Result.lose() end

        -- Black screen fade
        if kn == Vid.boKey then Vid.blackout() end

        -- Hold streaks on/off
        if kn == Notes.key then Notes.setEnabled(not Notes.enabled) end

        -- Dodge: plays the animation, nothing else
        if kn == Pose.dodgeKey then F.playDodge() end

        -- Intro / preset / cheat-sheet hotkeys
        Keys.handle(kn)

        -- Section switching keybinds
        local switched = false
        if kn == sectionNextKey then
            currentSectionIdx = currentSectionIdx + 1
            if currentSectionIdx > #sections then currentSectionIdx = 1 end
            switched = true
        elseif kn == sectionPrevKey then
            currentSectionIdx = currentSectionIdx - 1
            if currentSectionIdx < 1 then currentSectionIdx = #sections end
            switched = true
        end
        if switched and sections[currentSectionIdx] then
            local sec = sections[currentSectionIdx]
            for _, row in ipairs(CurrentBindings) do
                local newId = sec.ids[row.dir]
                if newId and newId ~= "0" and newId ~= "" then
                    row.id = newId; F.destroyTrack(row.key)
                end
            end
            F.notify("§ " .. sec.name, "info")
            if F.refreshSectionsUI then F.refreshSectionsUI() end
        end
    end

    for _, row in ipairs(CurrentBindings) do
        if row.key == kn then
            if began then
                F.heldRows[row] = true
                F.notePress(row)
            elseif ended and F.heldRows[row] then
                F.heldRows[row] = nil
                F.noteRelease(row)
            end
        end
    end
end

-- ============================================================
--  CHARACTER SETUP
-- ============================================================
function F.buildPreviewClone(char)
    if not previewCloneContainer then return end
    if previewClone then previewClone:Destroy(); previewClone = nil end

    local wasArchivable = char.Archivable
    if not wasArchivable then char.Archivable = true end
    local ok, clone = pcall(function() return char:Clone() end)
    if not wasArchivable then char.Archivable = wasArchivable end

    if not ok or not clone then
        F.notify("Preview failed: character isn't clonable right now", "error")
        return
    end

    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end
    end
    clone.Name = "PreviewClone"
    clone.Parent = previewCloneContainer

    local hum = clone:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function() hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end)
        pcall(function() hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff end)
        pcall(function() hum.RequiresNeck = false end)
        pcall(function() hum.BreakJointsOnDeath = false end)
        pcall(function() hum.Health = hum.MaxHealth end)
        pcall(function() hum.EvaluateStateMachine = false end)
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
        previewAnimator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
    else
        F.notify("Preview clone has no Humanoid — can't animate it", "warn")
    end

    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("BasePart") then
            d.CanCollide = false; d.Massless = true; d.Anchored = false
        end
    end
    local root = clone:FindFirstChild("HumanoidRootPart") or clone.PrimaryPart
    if root then root.Anchored = true; clone.PrimaryPart = root end

    local okPivot = pcall(function()
        clone:PivotTo(CFrame.new(0, 3, 0))
    end)
    if not okPivot then
        local hrp = clone:FindFirstChild("HumanoidRootPart") or clone.PrimaryPart
        if hrp then clone:SetPrimaryPartCFrame(CFrame.new(0, 3, 0)) end
    end

    previewClone = clone
end

function F.setupCharacter(char)
    F.cleanupAll(); character = char
    FNFCamera:SetPlayerCharacter(char)
    pcall(function() character:WaitForChild("HumanoidRootPart", 10) end)
    animator = F.getAnimator(char)
    if not animator then return end
    F.initFace(char)
    Hold.clear(false)
    Hold.watch(animator)
    task.defer(F.preloadBinds)
    if legsLocked then F.applyLegsLock(true) end
    table.insert(connections, F.own(UserInputService.InputBegan:Connect(F.onInput)))
    table.insert(connections, F.own(UserInputService.InputEnded:Connect(F.onInput)))
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then table.insert(connections, F.own(hum.Died:Connect(F.cleanupAll))) end
    task.defer(F.buildPreviewClone, char)

    if spacing then spacing:Destroy() end
    if SpacingSystem then
        spacing = SpacingSystem.new(char)
        -- the UI is static; it reads the new instance through `spacing`
        if spacing and currentTarget and currentTarget.Character then
            spacing:SetOpponent(currentTarget.Character)
        end
    end

    if Split.enabled then Split.refreshClones() end
    if Boss.active then Boss.exit() end
    if Ride.enabled then Ride.unlock("respawned") end
    if Fly.enabled then Fly.stop("you respawned") end
    Result.token = Result.token + 1
    Result.winTrack, Result.sitTrack = nil, nil
    if Vid.stage.on then task.delay(0.5, function() pcall(Vid.stageRefresh) end) end
    Cut.tracks = {}
    Cut.trackOwner = nil
    cutterTrack = nil
    pcall(F.cutterLoadTrack)          -- warm every note's animation again
    if Cut.wm then task.delay(1, function()
        Cut.buildClone()
        Cut.editDir(Cut.selDir, true)
    end) end
    Health.reset()
    Idle.resume()                     -- a looping idle comes back after you respawn
    Copy.links = {}                   -- the old copies went with the old character
    if Copy.on then task.delay(0.6, Copy.remirror) end
    F.log("Character ready.")
    F.notify("Character loaded — ready to inject", "success")
    F.startProximityBlock()
    F.startFightLoop()
end

-- ============================================================
--  UI HELPER FUNCTIONS
-- ============================================================
function F.uiCorner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = r or UDim.new(0,12); c.Parent = p
end
function F.uiStroke(p, col, th)
    local s = Instance.new("UIStroke"); s.Color = col; s.Thickness = th or 1; s.Transparency = 0.3; s.Parent = p; return s
end
function F.uiGradient(p, c1, c2, rot)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(c1 or Color3.fromRGB(255,255,255), c2 or Color3.fromRGB(200,200,220))
    g.Rotation = rot or 90
    g.Parent = p; return g
end
function F.makeLabel(parent, text, pos, size, color, xAlign, ts)
    local l = Instance.new("TextLabel")
    l.Size = size; l.Position = pos; l.BackgroundTransparency = 1
    l.Text = text; l.TextColor3 = color or Color3.fromRGB(210,210,225)
    l.TextSize = ts or 11; l.Font = Enum.Font.GothamMedium
    l.TextXAlignment = xAlign or Enum.TextXAlignment.Center
    l.Parent = parent; return l
end
function F.makeBtn(parent, text, pos, size, bg, tc, ts)
    local b = Instance.new("TextButton")
    b.Size = size; b.Position = pos
    b.BackgroundColor3 = bg or Color3.fromRGB(38, 36, 52)
    b.BackgroundTransparency = 0.08
    b.Text = text; b.TextColor3 = tc or Color3.fromRGB(238, 238, 248)
    b.Font = Enum.Font.GothamMedium; b.TextSize = ts or 12
    b.BorderSizePixel = 0; b.Parent = parent; b.AutoButtonColor = false
    F.uiCorner(b, UDim.new(0, 8))

    -- single hairline, no heavy gradient stack
    local edge = F.uiStroke(b, Color3.fromRGB(255, 255, 255), 1)
    edge.Transparency = 0.86

    -- thin accent bar down the left edge
    local tab = Instance.new("Frame")
    tab.Size = UDim2.new(0, 2, 1, -10); tab.Position = UDim2.new(0, 0, 0, 5)
    tab.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    tab.BackgroundTransparency = 0.75
    tab.BorderSizePixel = 0; tab.Parent = b
    F.uiCorner(tab, UDim.new(1, 0))

    local baseSize = size
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.13, Enum.EasingStyle.Quad), {
            BackgroundTransparency = 0
        }):Play()
        TweenService:Create(edge, TweenInfo.new(0.13), { Transparency = 0.55 }):Play()
        TweenService:Create(tab, TweenInfo.new(0.13), { BackgroundTransparency = 0.15 }):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
            BackgroundTransparency = 0.08, Size = baseSize
        }):Play()
        TweenService:Create(edge, TweenInfo.new(0.18), { Transparency = 0.86 }):Play()
        TweenService:Create(tab, TweenInfo.new(0.18), { BackgroundTransparency = 0.75 }):Play()
    end)
    b.MouseButton1Down:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.05), {
            Size = UDim2.new(baseSize.X.Scale, baseSize.X.Offset - 3,
                             baseSize.Y.Scale, baseSize.Y.Offset - 2)
        }):Play()
    end)
    b.MouseButton1Up:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Size = baseSize }):Play()
    end)

    return b
end
function F.makeDivider(parent, yPos, color)
    local d = Instance.new("Frame"); d.Size = UDim2.new(1,-24,0,1)
    d.Position = UDim2.new(0,12,0,yPos)
    d.BackgroundColor3 = color or Color3.fromRGB(255,255,255)
    d.BackgroundTransparency = 0.88
    d.BorderSizePixel = 0; d.Parent = parent
    return d
end
function F.makeBox(parent, pos, size, placeholder, default)
    local b = Instance.new("TextBox")
    b.Size = size; b.Position = pos
    b.BackgroundColor3 = Color3.fromRGB(12, 11, 18)
    b.BackgroundTransparency = 0.25
    b.PlaceholderText = placeholder or ""
    b.PlaceholderColor3 = Color3.fromRGB(105, 105, 125)
    b.Text = default or ""; b.TextColor3 = Color3.fromRGB(240, 240, 250)
    b.ClearTextOnFocus = false; b.Font = Enum.Font.Gotham; b.TextSize = 11
    b.BorderSizePixel = 0
    b.Parent = parent; F.uiCorner(b, UDim.new(0, 6))

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = b

    local edge = F.uiStroke(b, Color3.fromRGB(255, 255, 255), 1)
    edge.Transparency = 0.88

    b.Focused:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.13), { BackgroundTransparency = 0.05 }):Play()
        TweenService:Create(edge, TweenInfo.new(0.13),
            { Transparency = 0.25, Color = THEMES[currentThemeName].accent }):Play()
    end)
    b.FocusLost:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.18), { BackgroundTransparency = 0.25 }):Play()
        TweenService:Create(edge, TweenInfo.new(0.18),
            { Transparency = 0.88, Color = Color3.fromRGB(255, 255, 255) }):Play()
    end)
    return b
end

-- Every slider used to add its own InputChanged + InputEnded listener to
-- UserInputService and keep them for good: with the panel's sliders that
-- was dozens of callbacks on every mouse movement, and a whole new set
-- each time a load or import rebuilt the panel. One pair now serves
-- whichever slider is being dragged.
function F.hookSliderDrag()
    if F.sliderHooked then return end
    F.sliderHooked = true
    F.own(UserInputService.InputChanged:Connect(function(input)
        local drag = F.sliderDrag
        if drag and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            drag(input.Position.X)
        end
    end))
    F.own(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            F.sliderDrag = nil
        end
    end))
end

function F.makeSlider(parent, pos, size, minVal, maxVal, default, onChange)
    local track = Instance.new("Frame")
    track.Size = size; track.Position = pos
    track.BackgroundColor3 = Color3.fromRGB(255,255,255)
    track.BackgroundTransparency = 0.85
    track.BorderSizePixel = 0; track.Active = true
    track.Parent = parent; F.uiCorner(track, UDim.new(1,0))
    F.uiStroke(track, Color3.fromRGB(255,255,255), 1).Transparency = 0.85

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = Color3.fromRGB(255,80,180)
    fill.BackgroundTransparency = 0.35
    fill.BorderSizePixel = 0; fill.Size = UDim2.new(0,0,1,0)
    fill.Parent = track; F.uiCorner(fill, UDim.new(1,0))
    F.regBg(fill)

    local handle = Instance.new("Frame")
    handle.Size = UDim2.new(0,18,0,18)
    handle.AnchorPoint = Vector2.new(0.5,0.5)
    handle.Position = UDim2.new(0,0,0.5,0)
    handle.BackgroundColor3 = Color3.fromRGB(255,255,255)
    handle.BackgroundTransparency = 0.15
    handle.BorderSizePixel = 0; handle.ZIndex = 2
    handle.Parent = track; F.uiCorner(handle, UDim.new(1,0))
    local hStroke = F.uiStroke(handle, Color3.fromRGB(255,80,180), 1.5)
    hStroke.Transparency = 0.2
    F.regStroke(hStroke)
    local handleDot = Instance.new("Frame")
    handleDot.Size = UDim2.new(0,6,0,6); handleDot.AnchorPoint = Vector2.new(0.5,0.5)
    handleDot.Position = UDim2.new(0.5,0,0.5,0)
    handleDot.BackgroundColor3 = Color3.fromRGB(255,80,180)
    handleDot.BackgroundTransparency = 0.2
    handleDot.BorderSizePixel = 0; handleDot.Parent = handle
    F.uiCorner(handleDot, UDim.new(1,0)); F.regBg(handleDot)

    local value = default

    local function setValue(v, fire)
        v = math.clamp(v, minVal, maxVal)
        value = v
        local pct = (maxVal > minVal) and (v - minVal) / (maxVal - minVal) or 0
        fill.Size = UDim2.new(pct, 0, 1, 0)
        handle.Position = UDim2.new(pct, 0, 0.5, 0)
        if fire and onChange then onChange(v) end
    end

    local function updateFromX(x)
        local abs = track.AbsolutePosition.X
        local w   = track.AbsoluteSize.X
        if w <= 0 then return end
        local pct = math.clamp((x - abs) / w, 0, 1)
        setValue(minVal + pct * (maxVal - minVal), true)
    end

    -- The slider in hand is whichever one F.sliderDrag points at; the two
    -- listeners that follow the pointer are shared (F.hookSliderDrag).
    local function tryBegin(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            F.sliderDrag = updateFromX
            updateFromX(input.Position.X)
        end
    end

    track.InputBegan:Connect(tryBegin)
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            F.sliderDrag = updateFromX
        end
    end)
    F.hookSliderDrag()

    setValue(default, false)

    return { track = track, fill = fill, handle = handle, setValue = setValue, getValue = function() return value end }
end

-- One row per extra animation: an ID box, a % box (weighted mode only),
-- a test button and a remove button. Edits save straight into row.alts.
function F.refreshRowAltList(row, listFrame)
    for _, c in ipairs(listFrame:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
    end
    local weighted = (row.mode == "WEIGHTED")

    if #row.alts == 0 then
        local hint = F.makeLabel(listFrame, "No extra animations. Press + ANIM to add one.",
            UDim2.new(0,0,0,0), UDim2.new(1,-4,0,22), Color3.fromRGB(120,120,140),
            Enum.TextXAlignment.Center, 9)
        hint.LayoutOrder = 1
        return
    end

    for j, alt in ipairs(row.alts) do
        local entry = Instance.new("Frame")
        entry.Size = UDim2.new(1,-4,0,26)
        entry.BackgroundColor3 = Color3.fromRGB(24,22,33)
        entry.BackgroundTransparency = 0.2
        entry.BorderSizePixel = 0
        entry.LayoutOrder = j
        entry.Parent = listFrame
        F.uiCorner(entry, UDim.new(0,5))

        F.makeLabel(entry, "#" .. (j + 1), UDim2.new(0,4,0,0), UDim2.new(0,26,1,0),
            Color3.fromRGB(150,150,170), Enum.TextXAlignment.Left, 9)

        local idW = weighted and 190 or 250
        local idBox = F.makeBox(entry, UDim2.new(0,30,0,2), UDim2.new(0,idW,0,22), "animation ID", alt.id)
        idBox.TextSize = 10
        local a = alt
        idBox.FocusLost:Connect(function()
            a.id = (idBox.Text:gsub("%D", ""))
            idBox.Text = a.id
        end)

        if weighted then
            local pct = F.makeBox(entry, UDim2.new(0,30 + idW + 4,0,2), UDim2.new(0,52,0,22), "%",
                tostring(alt.chance or 0))
            pct.TextSize = 10
            pct.FocusLost:Connect(function()
                a.chance = math.clamp(tonumber(pct.Text) or 0, 0, 100)
                pct.Text = tostring(a.chance)
                F.refreshRowAltList(row, listFrame)
            end)
        end

        local test = F.makeBtn(entry, ">", UDim2.new(1,-52,0,2), UDim2.new(0,24,0,22),
            Color3.fromRGB(0,180,230), nil, 10)
        test.MouseButton1Down:Connect(function()
            if a.id ~= "" then F.playAnim(row.key, a.id, row.speedMult, row.holdLoop); F.hitArrow(row.dir) end
        end)
        test.MouseButton1Up:Connect(function() F.stopAnim(row.key); F.releaseArrow(row.dir) end)

        local rem = F.makeBtn(entry, "X", UDim2.new(1,-26,0,2), UDim2.new(0,24,0,22),
            Color3.fromRGB(170,35,35), nil, 10)
        rem.MouseButton1Click:Connect(function()
            table.remove(row.alts, j)
            row.cycleIdx = 0
            F.refreshRowAltList(row, listFrame)
        end)
    end

    if weighted then
        local total = 0
        for _, x in ipairs(row.alts) do total += (x.chance or 0) end
        local footer = F.makeLabel(listFrame,
            string.format("Extras total %d%%  -  main ID plays the other %d%%", total, math.max(0, 100 - total)),
            UDim2.new(0,0,0,0), UDim2.new(1,-4,0,16),
            (total > 100) and Color3.fromRGB(255,80,80) or Color3.fromRGB(140,140,160),
            Enum.TextXAlignment.Right, 9)
        footer.LayoutOrder = 9999
    end
end

-- ============================================================
--  ARROW HUD BUILD
-- ============================================================
-- One strip of four arrows. Yours carries the combo readout and the notes
-- that fly off it; the opponent's (isOpp) runs itself like the game's CPU.
function F.buildStrip(sg, isOpp, useSprites)
    local totalW = #ARROW_ORDER * Arrows.size + (#ARROW_ORDER - 1) * Arrows.gap

    -- one container holds all four, so they always move as a unit
    local holder = Instance.new("Frame")
    holder.Name = isOpp and "OpponentStrip" or "Strip"
    holder.Size = UDim2.new(0, totalW, 0, Arrows.size)
    holder.AnchorPoint = Vector2.new(0.5, 0.5)
    holder.Position = isOpp and UDim2.new(Arrows.oppX, Arrows.oppOffX, Arrows.oppY, Arrows.oppOffY)
        or UDim2.new(Arrows.x, Arrows.offX, Arrows.y, Arrows.offY)
    holder.BackgroundTransparency = 1
    holder.Active = true
    holder.ZIndex = F.silZ(62)
    holder.Parent = sg

    if not isOpp then
        -- notes render behind the arrows
        local noteLayer = Instance.new("Frame")
        noteLayer.Name = "Notes"
        noteLayer.Size = UDim2.new(0, totalW, 0, Arrows.size)
        noteLayer.BackgroundTransparency = 1
        noteLayer.ZIndex = F.silZ(61)
        noteLayer.Parent = holder
        Arrows.noteLayer = noteLayer

        -- combo readout above the strip
        local combo = Instance.new("TextLabel")
        combo.Size = UDim2.new(1, 0, 0, 30)
        combo.Position = UDim2.new(0, 0, 0, -44)
        combo.BackgroundTransparency = 1
        combo.Text = ""
        combo.TextColor3 = Color3.fromRGB(255, 255, 255)
        combo.Font = Enum.Font.GothamBlack; combo.TextSize = 26
        combo.TextStrokeTransparency = 0.4
        combo.TextTransparency = 1
        combo.ZIndex = F.silZ(64)
        combo.Parent = holder
        Arrows.comboLbl = combo
    end

    local frames = {}
    for i, dir in ipairs(ARROW_ORDER) do
        local colors = ARROW_COLORS[dir]
        local x = (i - 1) * (Arrows.size + Arrows.gap)

        local bg = Instance.new("Frame")
        bg.AnchorPoint = Vector2.new(0.5, 0.5)
        bg.Size = UDim2.new(0, Arrows.size, 0, Arrows.size)
        bg.Position = UDim2.new(0, x + Arrows.size / 2, 0.5, 0)
        bg.BackgroundColor3 = colors.idle
        bg.BackgroundTransparency = 0.3
        bg.BorderSizePixel = 0
        bg.ZIndex = F.silZ(63)
        bg.Parent = holder
        F.uiCorner(bg, UDim.new(0, 14))
        local stroke = F.uiStroke(bg, Color3.fromRGB(255,255,255), 1.5)
        stroke.Transparency = 0.5

        local grad = Instance.new("UIGradient")
        grad.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.1),
            NumberSequenceKeypoint.new(0.5, 0.35),
            NumberSequenceKeypoint.new(1, 0.15),
        })
        grad.Rotation = 90; grad.Parent = bg

        local glow = Instance.new("Frame")
        glow.Size = UDim2.new(1, 4, 1, 4); glow.AnchorPoint = Vector2.new(0.5, 0.5)
        glow.Position = UDim2.new(0.5, 0, 0.5, 0)
        glow.BackgroundTransparency = 0.7
        glow.BackgroundColor3 = colors.hit
        glow.BorderSizePixel = 0
        glow.ZIndex = F.silZ(62)
        glow.Visible = false
        glow.Parent = bg
        F.uiCorner(glow, UDim.new(0, 16))

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
        lbl.Text = ARROW_SYMBOLS[dir]
        lbl.TextColor3 = Color3.fromRGB(255,255,255)
        lbl.TextSize = 26; lbl.Font = Enum.Font.GothamBold
        lbl.ZIndex = F.silZ(64); lbl.Parent = bg

        -- FNF sprite: the real strum arrow stands in for the drawn tile. The
        -- tile stays underneath, invisible, so dragging, the hit pop and the
        -- strip's lean all keep working through it.
        local spr, cover = nil, nil
        if useSprites then
            spr = Instance.new("ImageLabel")
            spr.Name = "Sprite"
            spr.AnchorPoint = Vector2.new(0.5, 0.5)
            spr.Position = UDim2.new(0.5, 0, 0.5, 0)
            spr.Size = UDim2.new(Skin.strumScale, 0, Skin.strumScale, 0)
            spr.BackgroundTransparency = 1
            spr.Image = Skin.img("strum_static_" .. dir)
            spr.ZIndex = F.silZ(64)
            spr.Parent = bg
            bg.BackgroundTransparency = 1
            stroke.Enabled = false
            lbl.Visible = false

            -- hold-cover sparks, over the arrow while a hold note is held
            cover = Instance.new("ImageLabel")
            cover.Name = "HoldCover"
            cover.AnchorPoint = Vector2.new(0.5, 0.5)
            cover.Position = UDim2.new(0.5, 0, 0.5, 0)
            cover.Size = UDim2.new(Skin.coverScale, 0, Skin.coverScale, 0)
            cover.BackgroundTransparency = 1
            cover.Visible = false
            cover.ZIndex = F.silZ(66)
            cover.Parent = bg
        end

        frames[dir] = { bg = bg, lbl = lbl, stroke = stroke, glow = glow, slot = x, spr = spr,
                        cover = cover, cpu = isOpp, anim = "static", animT = 0 }
    end
    return holder, frames
end

function F.buildArrowHud()
    local old = PlayerGui:FindFirstChild("FNFArrowHud")
    if old then old:Destroy() end

    local sg = F.own(Instance.new("ScreenGui"))
    sg.Name = "FNFArrowHud"; sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = F.silZ(60)
    sg.Parent = PlayerGui

    -- the game's arrows if they've been imported, the drawn tiles if not
    local useSprites = Skin.arrowsReady()
    Skin.missing = Arrows.sprites and not useSprites

    local holder
    holder, arrowHudFrames = F.buildStrip(sg, false, useSprites)
    Arrows.container = holder
    if Mobile.active and Mobile.hideStrip then holder.Visible = false end
    Arrows.oppContainer, Arrows.oppFrames = F.buildStrip(sg, true, useSprites)
    Arrows.oppContainer.Visible = F.oppStripWanted()

    -- drag either strip anywhere on screen; each keeps its own spot
    local drag = nil
    for _, strip in ipairs({ { holder, false }, { Arrows.oppContainer, true } }) do
        local h, isOpp = strip[1], strip[2]
        h.InputBegan:Connect(function(input)
            if not Arrows.draggable then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                drag = { h = h, opp = isOpp, start = input.Position, pos = h.Position }
            end
        end)
    end
    -- the size and spacing sliders rebuild the strips on every step of a
    -- drag; the last build's two listeners go before the new ones arrive
    for _, c in ipairs(Arrows.dragConns or {}) do c:Disconnect() end
    Arrows.dragConns = {
        F.own(UserInputService.InputChanged:Connect(function(input)
            if not drag then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch then
                local d = input.Position - drag.start
                local p = UDim2.new(drag.pos.X.Scale, drag.pos.X.Offset + d.X, drag.pos.Y.Scale, drag.pos.Y.Offset + d.Y)
                drag.h.Position = p
                if drag.opp then
                    Arrows.oppX, Arrows.oppOffX, Arrows.oppY, Arrows.oppOffY = p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset
                else
                    Arrows.x, Arrows.offX, Arrows.y, Arrows.offY = p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset
                end
            end
        end)),
        F.own(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                drag = nil
            end
        end)),
    }

    F.startArrowLoops()
    F.startStrumLoop()
end

-- ============================================================
--  STRUM ENGINE — the arrows animate the way the game's do
--  At rest; "press" on a press with nothing to hit; "confirm"
--  on a hit; then the held glow looping, with the hold-cover
--  sparks, for as long as a hold note is held. The opponent's
--  strip goes back to rest once its confirm has played, like
--  the CPU's in the game.
-- ============================================================
function F.strumPlay(f, anim)
    f.anim, f.animT = anim, os.clock()
end

-- One frame of a strum animation. Sprite folders made before the arrows
-- were cut frame by frame fall back to the few frames they have.
function F.strumImage(dir, anim, i)
    return Skin.img("strum_" .. anim .. "_" .. dir .. "_" .. i)
        or (anim == "confirm" and Skin.img(i <= 2 and ("strum_confirm1_" .. dir) or ("strum_confirm2_" .. dir)))
        or (anim == "hold" and Skin.img("strum_confirm2_" .. dir))
        or (anim == "press" and Skin.img("strum_press_" .. dir))
        or nil
end

function F.strumFrame(f, dir, now)
    local anim = f.anim or "static"
    local t = now - (f.animT or 0)
    local img
    if anim == "confirm" then
        local i = math.floor(t * 24) + 1
        if i > 4 and f.holding then
            F.strumPlay(f, "hold"); anim, t = "hold", 0
        elseif i > 4 and f.cpu and t > 0.22 then
            F.strumPlay(f, "static"); anim = "static"
        else
            img = F.strumImage(dir, "confirm", math.min(i, 4))
        end
    elseif anim == "press" then
        img = F.strumImage(dir, "press", math.min(math.floor(t * 24) + 1, 4))
    end
    if anim == "hold" then img = F.strumImage(dir, "hold", (math.floor(t * 24) % 4) + 1) end
    if anim == "static" then img = Skin.img("strum_static_" .. dir) end
    if img and f.shown ~= img then
        f.shown = img
        f.spr.Image = img
    end
end

function F.coverFrame(f, dir, now)
    local c = f.cover
    local a = f.coverAnim
    if not a then
        if c.Visible then c.Visible = false end
        return
    end
    local t = now - f.coverT
    if a == "start" and t >= 1 / 24 then
        a, f.coverAnim, f.coverT, t = "loop", "loop", now, 0
    end
    local name
    if a == "start" then
        name = "cover_start_" .. dir .. "_1"
    elseif a == "loop" then
        name = "cover_loop_" .. dir .. "_" .. ((math.floor(t * 24) % 4) + 1)
    else
        local i = math.floor(t * 24) + 1
        if i > 8 then
            f.coverAnim = nil
            c.Visible = false
            return
        end
        name = "cover_end_" .. dir .. "_" .. i
    end
    local img = Skin.img(name)
    if img then
        if f.coverShown ~= img then f.coverShown = img; c.Image = img end
        if not c.Visible then c.Visible = true end
    end
end

function F.strumStep()
    local now = os.clock()
    for _, set in ipairs({ arrowHudFrames, Arrows.oppFrames or {} }) do
        for dir, f in pairs(set) do
            if f.spr and f.spr.Parent then F.strumFrame(f, dir, now) end
            if f.cover and f.cover.Parent then F.coverFrame(f, dir, now) end
        end
    end
end

function F.startStrumLoop()
    if Arrows.strumConn then return end
    Arrows.strumConn = F.own(RunService.RenderStepped:Connect(function() pcall(F.strumStep) end))
end

-- A hold note starts on this arrow: the held glow after the confirm, and
-- the sparks.
function F.strumHoldStart(f, dir)
    f.holding = true
    if f.spr and f.anim ~= "confirm" and f.anim ~= "hold" then F.strumPlay(f, "confirm") end
    if f.cover and Skin.img("cover_loop_" .. dir .. "_1") then
        f.coverAnim, f.coverT = "start", os.clock()
    end
end

-- ...and ends: made it (the sparks burst off) or dropped (they just stop).
function F.strumHoldEnd(f, dir, made)
    f.holding = false
    if f.cover then
        if made and f.coverAnim and Skin.img("cover_end_" .. dir .. "_1") then
            f.coverAnim, f.coverT = "end", os.clock()
        else
            f.coverAnim = nil
        end
    end
    if f.spr and f.anim == "hold" then
        if f.down or f.cpu then
            -- key still down (or the CPU's strip): the last confirm frame, which
            -- the CPU's strip then lets go of by itself
            f.anim, f.animT = "confirm", os.clock() - 4 / 24
        else
            F.strumPlay(f, "static")
        end
    end
end

-- A hold trail: the game's body piece stretched to length with its end cap
-- at the far end. sign -1: it runs up from where it starts; +1: down.
function F.makeTrail(parent, dir, sign, size, sprites)
    local w = size * 52 / 157     -- as wide, next to the arrow, as in the game
    local tail = Instance.new("Frame")
    tail.BackgroundTransparency = 1
    tail.AnchorPoint = Vector2.new(0.5, sign < 0 and 1 or 0)
    tail.ClipsDescendants = true
    tail.ZIndex = 2
    tail.Parent = parent
    local piece, cap
    local pieceImg = sprites and Skin.img("hold_piece_" .. dir)
    if pieceImg then
        piece = Instance.new("ImageLabel"); piece.Image = pieceImg
        cap = Instance.new("ImageLabel")
        cap.Image = Skin.img("hold_end_" .. dir .. (sign < 0 and "_flip" or "")) or ""
        piece.BackgroundTransparency, cap.BackgroundTransparency = 1, 1
    else
        piece, cap = Instance.new("Frame"), Instance.new("Frame")
        for _, p in ipairs({ piece, cap }) do
            p.BackgroundColor3 = ARROW_COLORS[dir].hit
            p.BorderSizePixel = 0
        end
    end
    piece.ZIndex, cap.ZIndex = 2, 2
    local capH = w * 0.9
    cap.Size = UDim2.new(1, 0, 0, capH)
    piece.Parent, cap.Parent = tail, tail
    return { tail = tail, piece = piece, cap = cap, w = w, capH = capH, sign = sign }
end

function F.sizeTrail(t, px)
    t.tail.Size = UDim2.new(0, t.w, 0, px)
    if t.sign < 0 then   -- runs up: cap on top
        t.cap.Position = UDim2.new(0, 0, 0, 0)
        t.piece.Position = UDim2.new(0, 0, 0, t.capH)
    else                 -- runs down: cap at the bottom
        t.piece.Position = UDim2.new(0, 0, 0, 0)
        t.cap.Position = UDim2.new(0, 0, 0, px - t.capH)
    end
    t.piece.Size = UDim2.new(1, 0, 0, math.max(0, px - t.capH))
end

-- 0 solid .. 1 gone
function F.fadeTrail(t, alpha)
    for _, p in ipairs({ t.piece, t.cap }) do
        if p:IsA("ImageLabel") then p.ImageTransparency = alpha else p.BackgroundTransparency = alpha end
    end
end

-- ============================================================
--  OPPONENT STRIP
-- ============================================================
function F.oppStripWanted()
    return Arrows.oppShow
end

function F.refreshOppStrip()
    if Arrows.oppContainer then Arrows.oppContainer.Visible = F.oppStripWanted() end
end

-- the opponent's arrow lights for a note they sing (hold: they're holding it)
function F.oppHit(dir, hold)
    local f = Arrows.oppFrames and Arrows.oppFrames[dir]
    if not f then return end
    if f.spr then
        F.strumPlay(f, "confirm")
    else
        -- drawn arrows: a flash in the arrow's colour
        f.bg.BackgroundColor3 = ARROW_COLORS[dir].hit
        TweenService:Create(f.bg, TweenInfo.new(0.25), { BackgroundColor3 = ARROW_COLORS[dir].idle }):Play()
    end
    if hold then F.strumHoldStart(f, dir) end
end

-- Free play: when your RP opponent poses, their side reacts: their strip
-- lights (if it's on) and the opponent on the stage sings a note.
function F.oppReact()
    local dir = ARROW_ORDER[math.random(1, #ARROW_ORDER)]
    if Arrows.oppShow then F.oppHit(dir, false) end
    if Chars.slot("opp") then
        Chars.sing(dir, "opp")
        task.delay(0.25, function() Chars.release(dir, "opp") end)
    end
end

-- A note leaves the arrow and travels off in the chosen direction.
function F.spawnNote(dir)
    if not Arrows.noteEnabled or not Arrows.noteLayer then return end
    local f = arrowHudFrames[dir]
    if not f then return end
    local colors = ARROW_COLORS[dir]
    local sign = (Arrows.noteDir == "UP") and -1 or 1
    local travel = Arrows.noteSpeed * Arrows.noteLife

    if f.spr then
        -- FNF sprite: the game's coloured note flies off and fades. It keeps
        -- its shape the whole way (no spin, no shrink, no streak), as a tap
        -- note does in the game.
        local side = Arrows.size * Skin.strumScale
        local note = Instance.new("ImageLabel")
        note.AnchorPoint = Vector2.new(0.5, 0.5)
        note.Size = UDim2.new(0, side, 0, side)
        note.Position = UDim2.new(0, f.slot + Arrows.size / 2, 0.5, 0)
        note.BackgroundTransparency = 1
        note.Image = Skin.img("note_" .. dir) or ""
        note.ZIndex = F.silZ(61)
        note.Parent = Arrows.noteLayer
        TweenService:Create(note, TweenInfo.new(Arrows.noteLife, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, f.slot + Arrows.size / 2, 0.5, sign * travel),
            ImageTransparency = 1,
        }):Play()
        task.delay(Arrows.noteLife + 0.15, function()
            if note.Parent then note:Destroy() end
        end)
        return
    end

    local note = Instance.new("Frame")
    note.AnchorPoint = Vector2.new(0.5, 0.5)
    note.Size = UDim2.new(0, Arrows.size * 0.7, 0, Arrows.size * 0.7)
    note.Position = UDim2.new(0, f.slot + Arrows.size / 2, 0.5, 0)
    note.BackgroundColor3 = colors.hit
    note.BackgroundTransparency = 0.15
    note.BorderSizePixel = 0
    note.Rotation = 45
    note.ZIndex = F.silZ(61)
    note.Parent = Arrows.noteLayer
    F.uiCorner(note, UDim.new(0, 10))

    if Arrows.trail then
        local trail = Instance.new("Frame")
        trail.AnchorPoint = Vector2.new(0.5, sign > 0 and 1 or 0)
        trail.Size = UDim2.new(0, Arrows.size * 0.24, 0, 0)
        trail.Position = UDim2.new(0.5, 0, sign > 0 and 0 or 1, 0)
        trail.BackgroundColor3 = colors.hit
        trail.BackgroundTransparency = 0.55
        trail.BorderSizePixel = 0
        trail.Rotation = -45
        trail.ZIndex = F.silZ(60)
        trail.Parent = note
        TweenService:Create(trail, TweenInfo.new(Arrows.noteLife * 0.6, Enum.EasingStyle.Quad), {
            Size = UDim2.new(0, Arrows.size * 0.24, 0, Arrows.size * 1.6),
            BackgroundTransparency = 1,
        }):Play()
    end

    TweenService:Create(note, TweenInfo.new(Arrows.noteLife, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, f.slot + Arrows.size / 2, 0.5, sign * travel),
        BackgroundTransparency = 1,
        Rotation = 45 + sign * 60,
        Size = UDim2.new(0, Arrows.size * 0.4, 0, Arrows.size * 0.4),
    }):Play()

    task.delay(Arrows.noteLife + 0.15, function()
        if note and note.Parent then note:Destroy() end
    end)
end

-- Expanding ring where the arrow was struck.
function F.spawnSplash(dir)
    if not Arrows.splash then return end
    local f = arrowHudFrames[dir]
    if not f then return end

    if f.spr and Skin.img("splash_" .. dir .. "_1") then
        -- FNF sprite: the game's four-frame splash, played once over the arrow
        local sp = Instance.new("ImageLabel")
        sp.AnchorPoint = Vector2.new(0.5, 0.5)
        sp.Position = UDim2.new(0.5, 0, 0.5, 0)
        sp.Size = UDim2.new(Skin.splashScale, 0, Skin.splashScale, 0)
        sp.BackgroundTransparency = 1
        sp.ImageTransparency = 0.15
        sp.ZIndex = F.silZ(65)
        sp.Parent = f.bg
        task.spawn(function()
            for i = 1, 4 do
                local img = Skin.img("splash_" .. dir .. "_" .. i)
                if not img or not sp.Parent then break end
                sp.Image = img
                task.wait(1 / Skin.splashFps)
            end
            sp:Destroy()
        end)
        return
    end

    local ring = Instance.new("Frame")
    ring.AnchorPoint = Vector2.new(0.5, 0.5)
    ring.Size = UDim2.new(0, Arrows.size, 0, Arrows.size)
    ring.Position = UDim2.new(0.5, 0, 0.5, 0)
    ring.BackgroundTransparency = 1
    ring.ZIndex = F.silZ(65)
    ring.Parent = f.bg
    F.uiCorner(ring, UDim.new(0, 18))
    local rs = F.uiStroke(ring, ARROW_COLORS[dir].hit, 3)
    rs.Transparency = 0.1

    TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, Arrows.size * 2.1, 0, Arrows.size * 2.1),
    }):Play()
    local t = TweenService:Create(rs, TweenInfo.new(0.35), { Transparency = 1, Thickness = 0 })
    t:Play()
    t.Completed:Connect(function() if ring then ring:Destroy() end end)
end

function F.bumpCombo(dir)
    Arrows.comboCount = Arrows.comboCount + 1
    Arrows.lastHit = os.clock()

    -- lean the strip toward whichever side you hit
    if Arrows.tilt then
        local idx = table.find(ARROW_ORDER, dir) or 2
        local side = (idx - 2.5) / 1.5      -- -1 on the far left, +1 on the far right
        Arrows.tiltVel = Arrows.tiltVel + side * 26
    end

    local lbl = Arrows.comboLbl
    if not lbl or not Arrows.combo then return end
    if Arrows.comboCount < 2 then return end
    lbl.Text = Arrows.comboCount .. "x"
    lbl.TextColor3 = ARROW_COLORS[dir].hit
    lbl.TextTransparency = 0
    lbl.TextSize = 34
    TweenService:Create(lbl, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { TextSize = 26 }):Play()
end

function F.startArrowLoops()
    if F._arrowLoopsStarted then return end
    F._arrowLoopsStarted = true
    -- combo decay
    task.spawn(function()
        while F.alive do
            task.wait(0.2)
            if Arrows.comboCount > 0 and os.clock() - Arrows.lastHit > 1.8 then
                Arrows.comboCount = 0
                if Arrows.comboLbl then
                    TweenService:Create(Arrows.comboLbl, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
                end
            end
        end
    end)

    -- beat bob + strip lean
    task.spawn(function()
        local bobPhase = 0
        while F.alive do
            local dt = RunService.Heartbeat:Wait()
            local holder = Arrows.container
            if holder and holder.Parent then
                -- sprung lean back to level
                Arrows.tiltVel = Arrows.tiltVel + (-180 * Arrows.tiltPos - 16 * Arrows.tiltVel) * dt
                Arrows.tiltPos = Arrows.tiltPos + Arrows.tiltVel * dt
                holder.Rotation = Arrows.tilt and math.clamp(Arrows.tiltPos, -12, 12) or 0

                if Arrows.beatBob then
                    bobPhase = bobPhase + dt * (math.max(40, StatusState.bpm or 100) / 60) * math.pi * 2
                    local s = 1 + math.sin(bobPhase) * 0.035
                    local w = #ARROW_ORDER * Arrows.size + (#ARROW_ORDER - 1) * Arrows.gap
                    holder.Size = UDim2.new(0, w * s, 0, Arrows.size * s)
                end
            end
        end
    end)
end

-- ============================================================
--  MIC SPECTROGRAM SETUP
-- ============================================================
function F.setupMicSpectrogram()
    micAvailable = false
    local ok = pcall(function()
        micDeviceInput = F.own(Instance.new("AudioDeviceInput"))
        micDeviceInput.Parent = LocalPlayer

        micAnalyzer = F.own(Instance.new("AudioAnalyzer"))
        micAnalyzer.WindowSize = 1024
        micAnalyzer.Parent = LocalPlayer

        micWire = F.own(Instance.new("Wire"))
        micWire.SourceInstance = micDeviceInput
        micWire.TargetInstance = micAnalyzer
        micWire.Parent = micAnalyzer

        micDeviceInput.Active = true
    end)
    micAvailable = ok and micDeviceInput ~= nil and micAnalyzer ~= nil
    if not micAvailable then
        F.log("Mic spectrogram unavailable on this client/game — using animation-synced fallback")
    end
    return micAvailable
end

-- ============================================================
--  BEAT / VISUALIZER LOOPS
-- ============================================================
local eqBars, waveBars, beatDot, notesLayer = nil, nil, nil, nil

-- True when a panel widget can actually be seen: the panel is open and
-- everything above the widget is visible (its tab is the selected one,
-- the GUI isn't hidden by a cutscene). The loops below used to animate
-- around the clock; the spectrum alone made 400 tweens a second (20 bars,
-- 20 times a second) for bars on a tab nobody was looking at.
function F.vizShown(obj)
    if not guiVisible or not obj then return false end
    while obj do
        if obj:IsA("GuiObject") then
            if not obj.Visible then return false end
        elseif obj:IsA("LayerCollector") then
            return obj.Enabled
        end
        obj = obj.Parent
    end
    return false   -- ran off the top: it's been destroyed
end

function F.startVisualizerLoops()
    if F._vizLoopsStarted then return end
    F._vizLoopsStarted = true
    task.spawn(function()
        while F.alive do
            local speed = StatusState.playing and 0.08 or 0.22
            task.wait(speed)
            if eqBars and F.vizShown(eqBars[1]) then
                for _, bar in ipairs(eqBars) do
                    local h = StatusState.playing and (0.25 + math.random() * 0.75) or (0.08 + math.random() * 0.2)
                    TweenService:Create(bar, TweenInfo.new(speed, Enum.EasingStyle.Sine), {
                        Size = UDim2.new(1, 0, h, 0)
                    }):Play()
                end
            end
        end
    end)

    task.spawn(function()
        local t = 0
        while F.alive do
            local dt = RunService.Heartbeat:Wait()
            t = t + (StatusState.bpm / 60) * 0.03
            if waveBars and F.vizShown(waveBars[1]) then
                for i, bar in ipairs(waveBars) do
                    local h = 0.15 + 0.35 * (0.5 + 0.5 * math.sin(t + i * 0.6))
                    bar.Size = UDim2.new(1, 0, h, 0)
                end
            end
            -- spectrum bars glide to the heights the 20 Hz loop below sets,
            -- instead of that loop making a new Tween per bar per tick
            local targets = F.specTargets
            if targets and F.vizShown(specBars[1]) then
                local k = math.min(1, dt * 22)
                for i, bar in ipairs(specBars) do
                    local want = targets[i]
                    if want then
                        local cur = bar.Size.Y.Scale
                        bar.Size = UDim2.new(1, 0, cur + (want - cur) * k, 0)
                    end
                end
            end
        end
    end)

    task.spawn(function()
        while F.alive do
            local interval = 60 / math.max(1, StatusState.bpm)
            task.wait(interval)
            if beatDot and F.vizShown(beatDot) then
                beatDot.Size = UDim2.new(0, 22, 0, 22)
                TweenService:Create(beatDot, TweenInfo.new(interval * 0.85, Enum.EasingStyle.Quad), {
                    Size = UDim2.new(0, 10, 0, 10)
                }):Play()
            end
        end
    end)

    task.spawn(function()
        local symbols = { "♪", "♫", "♬", "♩" }
        while F.alive do
            task.wait(0.7 + math.random() * 0.8)
            if notesLayer and F.vizShown(notesLayer) then
                local n = Instance.new("TextLabel")
                n.Size = UDim2.new(0, 20, 0, 20)
                n.Position = UDim2.new(math.random(), 0, 1, 0)
                n.BackgroundTransparency = 1
                n.Text = symbols[math.random(1, #symbols)]
                -- coloured once, here. These live a few seconds, and putting
                -- each one in the themed list kept it there for good.
                n.TextColor3 = F.accentNow or THEMES[currentThemeName].accent
                n.TextTransparency = 0.2
                n.Font = Enum.Font.GothamBold
                n.TextSize = 14 + math.random(0, 10)
                n.ZIndex = F.silZ(0)
                n.Parent = notesLayer
                local tw = TweenService:Create(n, TweenInfo.new(3 + math.random()*2, Enum.EasingStyle.Linear), {
                    Position = UDim2.new(n.Position.X.Scale, 0, -0.15, 0),
                    TextTransparency = 1
                })
                tw:Play()
                tw.Completed:Connect(function() n:Destroy() end)
            end
        end
    end)

    task.spawn(function()
        while F.alive do
            RunService.Heartbeat:Wait()
            if vinylImage and F.vizShown(vinylImage) then
                local rpm
                if StatusState.playing and StatusState.speedMult then
                    rpm = vinylBaseRPM * StatusState.speedMult
                else
                    rpm = vinylBaseRPM * F.idleSpeedFromBPM()
                end
                vinylRotation = (vinylRotation + (rpm / 60) * 360 * (1/60)) % 360
                vinylImage.Rotation = vinylRotation
            end
        end
    end)

    task.spawn(function()
        while F.alive do
            task.wait(0.05)
            if #specBars > 0 and F.vizShown(specBars[1]) then
                -- only work out where each bar should be; the per-frame loop
                -- above moves them there
                local targets = F.specTargets or {}
                F.specTargets = targets
                if micAvailable and micAnalyzer then
                    local ok, spectrum = pcall(function() return micAnalyzer:GetSpectrum() end)
                    if ok and spectrum then
                        local n = #spectrum
                        for i = 1, #specBars do
                            local idx = math.max(1, math.floor((i / #specBars) * n))
                            local mag = spectrum[idx] or 0
                            targets[i] = math.clamp(mag * 2, 0.05, 1)
                        end
                    else
                        micAvailable = false
                    end
                else
                    for i = 1, #specBars do
                        local base = StatusState.playing and 0.3 or 0.08
                        targets[i] = base + math.random() * (StatusState.playing and 0.6 or 0.15)
                    end
                end
            end
        end
    end)

    task.spawn(function()
        while F.alive do
            task.wait(0.08 + math.random() * 0.15)
            if crtEnabled and crtOverlay then
                crtOverlay.BackgroundTransparency = 0.82 + math.random() * 0.08
            end
        end
    end)
end

-- ============================================================
--  DYNAMIC SPACING SYSTEM v2.0
-- ============================================================
-- ============================================================
--  DYNAMIC SPACING SYSTEM v3
--  You step IN when you sing. If you both sing, you both step
--  in and close the gap further. Spamming notes holds you there
--  — the return timer resets on every note. Stop playing and
--  after the cooldown you ease back to exactly where you began.
-- ============================================================
local EASE = {
    Linear    = function(a) return a end,
    SineOut   = function(a) return math.sin(a * math.pi / 2) end,
    SineInOut = function(a) return -(math.cos(math.pi * a) - 1) / 2 end,
    BackOut   = function(a)
        local c1, c3 = 1.70158, 2.70158
        a -= 1
        return 1 + c3 * a * a * a + c1 * a * a
    end,
    Snap      = function(a) return a < 0.5 and (a * 2) ^ 2 * 0.5 or 1 - ((1 - a) * 2) ^ 2 * 0.5 end,
}
local EASE_ORDER = { "SineOut", "SineInOut", "BackOut", "Snap", "Linear" }

SPACING = {
    enabled     = false,
    stepIn      = 2.2,    -- studs you close on your first note
    bothBonus   = 1.3,    -- extra studs when you're both singing
    stepTime    = 0.3,    -- how long the step in takes
    returnDelay = 3,      -- seconds of silence before you head back
    returnTime  = 0.9,    -- how long the walk back takes
    minGap      = 3,      -- never get closer than this to each other
    stepEase    = "SineOut",
    returnEase  = "SineInOut",
}

local function flatDirection(fromPos, toPos)
    local d = toPos - fromPos
    d = Vector3.new(d.X, 0, d.Z)
    if d.Magnitude < 1e-3 then return Vector3.new(0, 0, 1) end
    return d.Unit
end

-- Per-character movement state. The root is anchored only while we own it,
-- so limb animation is never touched.
local function makeSpacingRig(char)
    local root = char:WaitForChild("HumanoidRootPart")
    return {
        char = char, root = root,
        anchored = false, singing = false,
        home = root.Position,                  -- where they stood before any of this
        rotationOnly = root.CFrame - root.CFrame.Position,
        offset = 0,                            -- studs currently stepped in
        moving = false, moveStart = 0, moveDur = 0,
        moveEaseFn = EASE.SineOut,
        startPos = root.Position, endPos = root.Position,
        lastNote = 0, returning = false,
    }
end

SpacingSystem = {}
SpacingSystem.__index = SpacingSystem

function SpacingSystem.new(myCharacter)
    local self = setmetatable({}, SpacingSystem)
    self.A = makeSpacingRig(myCharacter)
    self.B = nil
    self._heartbeatConn = F.own(RunService.Heartbeat:Connect(function(dt) self:_update(dt) end))
    return self
end

function SpacingSystem:Destroy()
    if self._heartbeatConn then self._heartbeatConn:Disconnect() end
    self:_release(self.A)
    if self.B then self:_release(self.B) end
end

function SpacingSystem:SetOpponent(char)
    if self.B and self.B.char == char then return end
    if self.B then self:_goHome(self.B, true); self:_release(self.B) end
    self.B = char and makeSpacingRig(char) or nil
end

function SpacingSystem:SetEnabled(state)
    SPACING.enabled = state
    if not state then
        self:_goHome(self.A, true)
        if self.B then self:_goHome(self.B, true) end
    end
end

function SpacingSystem:_own(rig)
    if not rig.anchored then
        rig.anchored = true
        rig.root.Anchored = true
        rig.rotationOnly = rig.root.CFrame - rig.root.CFrame.Position
    end
end

function SpacingSystem:_release(rig)
    if rig.anchored then rig.anchored = false; rig.root.Anchored = false end
end

-- Move this rig to a given step-in distance from home, along the line
-- between the two characters.
function SpacingSystem:_moveTo(rig, otherRig, targetOffset, duration, easeName)
    if not otherRig then return end
    self:_own(rig)

    -- respect the minimum gap so they never overlap
    local gap = (rig.root.Position - otherRig.root.Position).Magnitude
    local room = math.max(0, gap - SPACING.minGap)
    local delta = targetOffset - rig.offset
    if delta > room then targetOffset = rig.offset + room end

    local axis = flatDirection(rig.home, otherRig.root.Position)
    rig.startPos   = rig.root.Position
    rig.endPos     = rig.home + axis * targetOffset
    rig.moveStart  = os.clock()
    rig.moveDur    = math.max(duration, 0.001)
    rig.moveEaseFn = EASE[easeName] or EASE.SineOut
    rig.moving     = true
    rig.offset     = targetOffset
end

function SpacingSystem:_goHome(rig, instant)
    rig.returning = true
    if instant then
        rig.offset = 0
        rig.moving = false
        if rig.anchored then
            rig.root.CFrame = CFrame.new(rig.home) * rig.rotationOnly
        end
        self:_release(rig)
        rig.returning = false
        return
    end
    local other = (rig == self.A) and self.B or self.A
    self:_moveTo(rig, other, 0, SPACING.returnTime, SPACING.returnEase)
end

function SpacingSystem:_rigs(who)
    if who == self.A.char then return self.A, self.B end
    if self.B and who == self.B.char then return self.B, self.A end
    return nil, nil
end

-- How far in this rig should be right now, given who's singing.
function SpacingSystem:_wantedOffset(rig, other)
    if not other then return 0 end
    local both = rig.singing and other.singing
    if not rig.singing then return rig.offset end
    return SPACING.stepIn + (both and SPACING.bothBonus or 0)
end

function SpacingSystem:OnSingStart(who)
    if not SPACING.enabled or not self.B then return end
    local rig, other = self:_rigs(who)
    if not rig or not other then return end

    rig.singing = true
    rig.lastNote = os.clock()
    rig.returning = false

    -- step in, or deepen the step if you're both going
    local want = self:_wantedOffset(rig, other)
    if math.abs(want - rig.offset) > 0.02 then
        self:_moveTo(rig, other, want, SPACING.stepTime, SPACING.stepEase)
    end

    -- the other side deepens too the moment you join in
    if other.singing then
        local ow = self:_wantedOffset(other, rig)
        if math.abs(ow - other.offset) > 0.02 then
            self:_moveTo(other, rig, ow, SPACING.stepTime, SPACING.stepEase)
        end
    end
end

-- Releasing a key does NOT send you home. Only the cooldown does, so
-- spamming notes keeps you planted where you stepped to.
function SpacingSystem:OnSingStop(who)
    if not self.B then return end
    local rig = self:_rigs(who)
    if not rig then return end
    rig.singing = false
    rig.lastNote = os.clock()
end

function SpacingSystem:_update(dt)
    local rigs = self.B and { self.A, self.B } or { self.A }
    local now = os.clock()

    for _, rig in ipairs(rigs) do
        local other = (rig == self.A) and self.B or self.A

        -- cooldown: quiet for long enough, head back to the start
        if SPACING.enabled and rig.offset ~= 0 and not rig.singing
            and not rig.returning and (now - rig.lastNote) > SPACING.returnDelay then
            self:_goHome(rig, false)
        end

        if rig.anchored then
            local pos
            if rig.moving then
                local a = math.clamp((now - rig.moveStart) / rig.moveDur, 0, 1)
                pos = rig.startPos:Lerp(rig.endPos, rig.moveEaseFn(a))
                if a >= 1 then
                    rig.moving = false
                    -- arrived home: give the character back to the player
                    if rig.returning and math.abs(rig.offset) < 0.02 then
                        rig.returning = false
                        self:_release(rig)
                    end
                end
            else
                pos = rig.endPos
            end
            if rig.anchored and pos then
                rig.root.CFrame = CFrame.new(pos) * rig.rotationOnly
            end
        end
    end
end

-- ============================================================
--  SPACING GUI
-- ============================================================
-- Built once from buildTab_Settings. It drives the SPACING config table and
-- the current `spacing` instance, so respawning never rebuilds the UI.
function F.buildSpacingUI(page, startY)
    if not page then return end

    F.makeDivider(page, startY, Color3.fromRGB(0,200,255))
    local title = F.makeLabel(page, "DYNAMIC SPACING", UDim2.new(0,8,0,startY+6),
        UDim2.new(1,-16,0,22), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Left, 12)
    title.Font = Enum.Font.GothamBold
    F.makeLabel(page, "Step in when you sing. Both singing closes the gap further. Spamming notes holds the position; going quiet sends you back.",
        UDim2.new(0,8,0,startY+28), UDim2.new(1,-16,0,40), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 9)

    local toggleBtn = F.makeBtn(page, SPACING.enabled and "SPACING ON" or "SPACING OFF",
        UDim2.new(0,8,0,startY+70), UDim2.new(0,190,0,28),
        SPACING.enabled and Color3.fromRGB(60,190,120) or Color3.fromRGB(35,35,55), nil, 10)
    toggleBtn.MouseButton1Click:Connect(function()
        if spacing then spacing:SetEnabled(not SPACING.enabled) else SPACING.enabled = not SPACING.enabled end
        toggleBtn.Text = SPACING.enabled and "SPACING ON" or "SPACING OFF"
        toggleBtn.BackgroundColor3 = SPACING.enabled and Color3.fromRGB(60,190,120) or Color3.fromRGB(35,35,55)
    end)

    local homeBtn = F.makeBtn(page, "RETURN NOW", UDim2.new(0,206,0,startY+70),
        UDim2.new(0,190,0,28), Color3.fromRGB(70,120,255), nil, 10)
    homeBtn.MouseButton1Click:Connect(function()
        if spacing then
            spacing:_goHome(spacing.A, false)
            if spacing.B then spacing:_goHome(spacing.B, false) end
        end
    end)

    local oppLbl = F.makeLabel(page, "Opponent: none", UDim2.new(0,8,0,startY+104),
        UDim2.new(1,-16,0,18), Color3.fromRGB(0,200,255), Enum.TextXAlignment.Left, 10)
    task.spawn(function()
        while F.alive do
            task.wait(0.5)
            if not oppLbl.Parent then break end
            local n = (spacing and spacing.B and spacing.B.char and spacing.B.char.Name)
                or (currentTarget and currentTarget.Name)
            oppLbl.Text = "Opponent: " .. (n or "none")
        end
    end)

    local searchBox = F.makeBox(page, UDim2.new(0,8,0,startY+126), UDim2.new(1,-16,0,28), "Search player name...")
    local results = Instance.new("ScrollingFrame")
    results.Size = UDim2.new(1,-16,0,84); results.Position = UDim2.new(0,8,0,startY+160)
    results.BackgroundColor3 = Color3.fromRGB(12,11,18); results.BackgroundTransparency = 0.25
    results.BorderSizePixel = 0; results.ScrollBarThickness = 3
    results.CanvasSize = UDim2.new(0,0,0,0); results.AutomaticCanvasSize = Enum.AutomaticSize.Y
    results.Parent = page; F.uiCorner(results, UDim.new(0,6))
    local rl = Instance.new("UIListLayout"); rl.Padding = UDim.new(0,2); rl.Parent = results

    local function refreshResults(q)
        for _, c in ipairs(results:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        if q == "" then return end
        q = q:lower()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Name:lower():find(q, 1, true) then
                local row = F.makeBtn(results, plr.Name, UDim2.new(0,2,0,0),
                    UDim2.new(1,-4,0,24), Color3.fromRGB(28,28,42), nil, 9)
                row.MouseButton1Click:Connect(function()
                    if not plr.Character then F.notify("They have no character yet", "warn"); return end
                    if spacing then spacing:SetOpponent(plr.Character) end
                    oppLbl.Text = "Opponent: " .. plr.Name
                    searchBox.Text = ""
                    refreshResults("")
                end)
            end
        end
    end
    searchBox:GetPropertyChangedSignal("Text"):Connect(function() refreshResults(searchBox.Text) end)

    local rows = {
        { key = "stepIn",      label = "STEP-IN DISTANCE",  min = 0,   max = 8,  fmt = "%.2f" },
        { key = "bothBonus",   label = "BOTH-SINGING BONUS",min = 0,   max = 6,  fmt = "%.2f" },
        { key = "stepTime",    label = "STEP TIME (s)",     min = 0.05,max = 2,  fmt = "%.2f" },
        { key = "returnDelay", label = "RETURN COOLDOWN (s)",min = 0.5,max = 10, fmt = "%.2f" },
        { key = "returnTime",  label = "RETURN TIME (s)",   min = 0.1, max = 3,  fmt = "%.2f" },
        { key = "minGap",      label = "MINIMUM GAP",       min = 0,   max = 10, fmt = "%.2f" },
    }
    for i, row in ipairs(rows) do
        local ry = startY + 254 + (i-1) * 42
        F.makeLabel(page, row.label, UDim2.new(0,8,0,ry), UDim2.new(0,220,0,18),
            Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
        local vlbl = F.makeLabel(page, string.format(row.fmt, SPACING[row.key]),
            UDim2.new(0,306,0,ry), UDim2.new(0,90,0,18), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Right, 10)
        F.regText(vlbl)
        local ck, cfm = row.key, row.fmt
        F.makeSlider(page, UDim2.new(0,8,0,ry+20), UDim2.new(1,-16,0,12),
            row.min, row.max, SPACING[row.key], function(v)
                SPACING[ck] = v
                vlbl.Text = string.format(cfm, v)
            end)
    end

    -- easing pickers
    local eY = startY + 254 + #rows * 42 + 6
    F.makeLabel(page, "STEP EASING", UDim2.new(0,8,0,eY), UDim2.new(1,-16,0,18),
        Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local stepBtns = {}
    for i, name in ipairs(EASE_ORDER) do
        local b = F.makeBtn(page, name, UDim2.new(0, 8 + (i-1) * 78, 0, eY + 20),
            UDim2.new(0, 74, 0, 24),
            name == SPACING.stepEase and Color3.fromRGB(255,80,180) or Color3.fromRGB(35,35,55), nil, 8)
        stepBtns[name] = b
        b.MouseButton1Click:Connect(function()
            SPACING.stepEase = name
            for n, bb in pairs(stepBtns) do
                bb.BackgroundColor3 = (n == name) and Color3.fromRGB(255,80,180) or Color3.fromRGB(35,35,55)
            end
        end)
    end

    F.makeLabel(page, "RETURN EASING", UDim2.new(0,8,0,eY+52), UDim2.new(1,-16,0,18),
        Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local retBtns = {}
    for i, name in ipairs(EASE_ORDER) do
        local b = F.makeBtn(page, name, UDim2.new(0, 8 + (i-1) * 78, 0, eY + 72),
            UDim2.new(0, 74, 0, 24),
            name == SPACING.returnEase and Color3.fromRGB(0,200,255) or Color3.fromRGB(35,35,55), nil, 8)
        retBtns[name] = b
        b.MouseButton1Click:Connect(function()
            SPACING.returnEase = name
            for n, bb in pairs(retBtns) do
                bb.BackgroundColor3 = (n == name) and Color3.fromRGB(0,200,255) or Color3.fromRGB(35,35,55)
            end
        end)
    end
end

-- ============================================================
--  MAIN GUI BUILD
-- ============================================================
-- ============================================================
--  ARMS TAB — animations mixed into your poses (everyone sees),
--  and the local arm aim (only you see)
-- ============================================================
function F.buildTab_Arms(pages)
    local pg = pages["💪 ARMS"]
    if not pg then return end

    local function heading(text, y, color)
        local l = F.makeLabel(pg, text, UDim2.new(0,8,0,y), UDim2.new(1,-16,0,20), color, Enum.TextXAlignment.Left, 12)
        l.Font = Enum.Font.GothamBold
        return l
    end
    local function note(text, y, h, color)
        F.makeLabel(pg, text, UDim2.new(0,8,0,y), UDim2.new(1,-16,0,h), color or Color3.fromRGB(130,130,150),
            Enum.TextXAlignment.Left, 9).TextWrapped = true
    end
    local function slider(y, label, minV, maxV, get, set, fmt)
        F.makeLabel(pg, label, UDim2.new(0,8,0,y), UDim2.new(0,280,0,18),
            Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
        local vlbl = F.makeLabel(pg, fmt(get()), UDim2.new(0,286,0,y), UDim2.new(0,110,0,18),
            Color3.fromRGB(255,80,180), Enum.TextXAlignment.Right, 10)
        F.regText(vlbl)
        F.makeSlider(pg, UDim2.new(0,8,0,y+20), UDim2.new(1,-16,0,12), minV, maxV, get(), function(v)
            set(v)
            vlbl.Text = fmt(v)
        end)
    end
    local function onOff(x, y, w, get, set, on, off)
        local b = F.makeBtn(pg, "", UDim2.new(0,x,0,y), UDim2.new(0,w,0,26), Color3.fromRGB(35,35,55), nil, 9)
        local function paint()
            b.Text = get() and on or off
            b.BackgroundColor3 = get() and Color3.fromRGB(60,190,120) or Color3.fromRGB(35,35,55)
        end
        paint()
        b.MouseButton1Click:Connect(function()
            set(not get())
            paint()
        end)
        return b
    end

    heading("ARMS", 6, Color3.fromRGB(255,110,230))
    note("Mix animations into each note's pose so your arms (or anything else) change while the pose keeps going. Everyone sees the mix: it's made of animations. LOCAL AIM further down turns your joints directly, so only you see that one.",
        26, 54)

    local readout = F.makeLabel(pg, "", UDim2.new(0,8,0,82), UDim2.new(1,-16,0,18),
        Color3.fromRGB(255,190,80), Enum.TextXAlignment.Left, 10)
    task.spawn(function()
        while F.alive and readout.Parent do
            Arms.measure(os.clock())
            readout.Text = string.format("speed %.1f notes/s   →   SPEED layers and the aim at %d%%",
                Arms.speed, math.floor(Arms.reachNow * 100 + 0.5))
            task.wait(0.2)
        end
    end)

    -- ── MIXED ANIMATIONS ──
    local y = 106
    F.makeDivider(pg, y, Color3.fromRGB(120,240,255))
    heading("MIXED ANIMATIONS: EVERYONE SEES THESE", y + 6, Color3.fromRGB(120,240,255))
    onOff(8, y + 30, 190, function() return Arms.mixOn end, function(v)
        Arms.mixOn = v
        if not v then Arms.mixStop() end
    end, "MIXED ANIMATIONS: ON", "MIXED ANIMATIONS: OFF")
    note("Every layer plays together with the note's pose. MIX %: how much of the result is the layer where it and the pose move the same joint (50 = half and half). AT %: the frame it freezes on, like a pose (blank = it plays through). MIX / OVER: blended into the pose, or laid on top of it. SPEED: more of it the faster you pose.",
        y + 60, 66)

    local hy = y + 130
    for _, h in ipairs({ { "ANIMATION ID", 8, 118 }, { "MIX %", 130, 44 }, { "AT %", 178, 44 },
                          { "LAYER", 226, 54 }, { "SPEED", 284, 54 } }) do
        F.makeLabel(pg, h[1], UDim2.new(0,h[2],0,hy), UDim2.new(0,h[3],0,16),
            Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 8)
    end

    y = hy + 18
    for _, dir in ipairs(ARROW_ORDER) do
        local lbl = F.makeLabel(pg, ARROW_SYMBOLS[dir] .. " " .. dir, UDim2.new(0,8,0,y), UDim2.new(0,100,0,18),
            ARROW_COLORS[dir].hit, Enum.TextXAlignment.Left, 10)
        lbl.Font = Enum.Font.GothamBold
        for i, slot in ipairs(Arms.mix[dir]) do
            local ry = y + 20 + (i - 1) * 30
            local idBox = F.makeBox(pg, UDim2.new(0,8,0,ry), UDim2.new(0,118,0,26), "layer " .. i .. " ID", slot.id)
            idBox.FocusLost:Connect(function()
                slot.id = string.gsub(idBox.Text or "", "%D", "")
                idBox.Text = slot.id
            end)
            local shareBox = F.makeBox(pg, UDim2.new(0,130,0,ry), UDim2.new(0,44,0,26), "50", tostring(slot.share))
            shareBox.FocusLost:Connect(function()
                slot.share = math.floor(math.clamp(tonumber(shareBox.Text) or slot.share, 0, 100) + 0.5)
                shareBox.Text = tostring(slot.share)
            end)
            local atBox = F.makeBox(pg, UDim2.new(0,178,0,ry), UDim2.new(0,44,0,26), "play",
                (slot.at >= 0) and tostring(slot.at) or "")
            atBox.FocusLost:Connect(function()
                local v = tonumber(atBox.Text)
                slot.at = v and math.floor(math.clamp(v, 0, 100) + 0.5) or -1
                atBox.Text = (slot.at >= 0) and tostring(slot.at) or ""
            end)
            local layerBtn = F.makeBtn(pg, "", UDim2.new(0,226,0,ry), UDim2.new(0,54,0,26), Color3.fromRGB(70,120,255), nil, 9)
            local function paintLayer() layerBtn.Text = slot.over and "OVER" or "MIX" end
            paintLayer()
            layerBtn.MouseButton1Click:Connect(function()
                slot.over = not slot.over
                paintLayer()
            end)
            onOff(284, ry, 54, function() return slot.speed end, function(v) slot.speed = v end, "SPEED", "—")
            local test = F.makeBtn(pg, "TEST", UDim2.new(0,342,0,ry), UDim2.new(0,54,0,26), Color3.fromRGB(35,35,55), nil, 9)
            test.MouseButton1Click:Connect(function() Arms.testLayer(slot) end)
        end
        y = y + 20 + 3 * 30 + 6
    end

    -- ── SPEED ──
    F.makeDivider(pg, y, Color3.fromRGB(255,190,80))
    heading("SPEED", y + 6, Color3.fromRGB(255,190,80))
    note("How fast you're posing, for SPEED layers and the local aim. Pose speed itself never changes.", y + 28, 16)
    local pct = function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end
    local nps = function(v) return string.format("%.1f /s", v) end
    local secs = function(v) return string.format("%.2f s", v) end
    local speedRows = {
        { key = "calm",    label = "HOW MUCH WHEN POSING SLOWLY", min = 0,    max = 1,  fmt = pct },
        { key = "full",    label = "HOW MUCH WHEN POSING FAST",   min = 0,    max = 1,  fmt = pct },
        { key = "slowNps", label = "SLOW: NOTES PER SECOND",      min = 0.5,  max = 8,  fmt = nps },
        { key = "fastNps", label = "FAST: NOTES PER SECOND",      min = 2,    max = 16, fmt = nps },
        { key = "window",  label = "SPEED MEASURED OVER",         min = 0.4,  max = 3,  fmt = secs },
        { key = "mixFade", label = "LAYERS LEAVE OVER",           min = 0.02, max = 1,  fmt = secs },
    }
    y = y + 48
    for _, r in ipairs(speedRows) do
        local key = r.key
        slider(y, r.label, r.min, r.max, function() return Arms[key] end, function(v) Arms[key] = v end, r.fmt)
        y = y + 42
    end

    -- ── LOCAL AIM ──
    y = y + 4
    F.makeDivider(pg, y, Color3.fromRGB(255,110,230))
    heading("LOCAL AIM: ONLY YOU SEE THIS", y + 6, Color3.fromRGB(255,110,230))
    note("Turns your arm joints to point where you set, seen from your camera, on top of everything else. Other players never see it, so leave it off while you set up the mix, or your screen won't match theirs.",
        y + 28, 40, Color3.fromRGB(255,190,80))
    y = y + 72
    onOff(8, y, 190, function() return Arms.enabled end, function(v)
        Arms.enabled = v
        if not v then Arms.active = false end
    end, "LOCAL AIM: ON", "LOCAL AIM: OFF")
    onOff(206, y, 190, function() return Arms.firstPerson end, function(v) Arms.firstPerson = v end,
        "SEEN IN FIRST PERSON: ON", "SEEN IN FIRST PERSON: OFF")
    y = y + 34

    local ARM_MODES = { "AUTO", "LEFT", "RIGHT", "BOTH" }
    local ARM_NAMES = { AUTO = "ARM: AUTO", LEFT = "LEFT ARM", RIGHT = "RIGHT ARM", BOTH = "BOTH ARMS" }
    local deg = function(v) return string.format("%d°", math.floor(v + 0.5)) end
    for _, dir in ipairs(ARROW_ORDER) do
        local cfg = Arms.dirs[dir]
        local lbl = F.makeLabel(pg, ARROW_SYMBOLS[dir] .. " " .. dir, UDim2.new(0,8,0,y), UDim2.new(0,70,0,26),
            ARROW_COLORS[dir].hit, Enum.TextXAlignment.Left, 11)
        lbl.Font = Enum.Font.GothamBold
        local armBtn = F.makeBtn(pg, ARM_NAMES[cfg.arm] or "ARM: AUTO", UDim2.new(0,80,0,y),
            UDim2.new(0,110,0,26), Color3.fromRGB(70,120,255), nil, 9)
        armBtn.MouseButton1Click:Connect(function()
            local i = table.find(ARM_MODES, cfg.arm) or 1
            cfg.arm = ARM_MODES[(i % #ARM_MODES) + 1]
            armBtn.Text = ARM_NAMES[cfg.arm]
        end)
        F.makeLabel(pg, "MAX %", UDim2.new(0,198,0,y), UDim2.new(0,44,0,26),
            Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 9)
        local maxBox = F.makeBox(pg, UDim2.new(0,244,0,y), UDim2.new(0,70,0,26), "100", tostring(cfg.max))
        maxBox.FocusLost:Connect(function()
            cfg.max = math.floor(math.clamp(tonumber(maxBox.Text) or 100, 0, 100) + 0.5)
            maxBox.Text = tostring(cfg.max)
        end)
        local test = F.makeBtn(pg, "TEST", UDim2.new(0,322,0,y), UDim2.new(0,74,0,26), Color3.fromRGB(35,35,55), nil, 9)
        test.MouseButton1Click:Connect(function() Arms.test(dir) end)
        slider(y + 32, "AIM AROUND  (0 right · 90 at you · 180 left · 270 away)", 0, 360,
            function() return cfg.h end, function(v) cfg.h = math.floor(v + 0.5) end, deg)
        slider(y + 74, "AIM UP / DOWN  (90 straight up · -90 straight down)", -90, 90,
            function() return cfg.v end, function(v) cfg.v = math.floor(v + 0.5) end, deg)
        y = y + 118
    end
    local aimRows = {
        { key = "blendIn",    label = "AIM GETS THERE IN",          min = 0.01, max = 0.5, fmt = secs },
        { key = "fadeOut",    label = "AIM GOES BACK IN",           min = 0.05, max = 1,   fmt = secs },
        { key = "straighten", label = "STRAIGHTEN THE ELBOW (R15)", min = 0,    max = 1,   fmt = pct },
    }
    for _, r in ipairs(aimRows) do
        local key = r.key
        slider(y, r.label, r.min, r.max, function() return Arms[key] end, function(v) Arms[key] = v end, r.fmt)
        y = y + 42
    end
end

-- ============================================================
--  STAGE TAB — Boyfriend, Girlfriend and the opponent
-- ============================================================
function F.buildTab_Stage(pages)
    local pg = pages["🎭 STAGE"]
    if not pg then return end

    local title = F.makeLabel(pg, "STAGE: BF, GF & OPPONENT", UDim2.new(0,8,0,6), UDim2.new(1,-16,0,20),
        Color3.fromRGB(255,110,230), Enum.TextXAlignment.Left, 12)
    title.Font = Enum.Font.GothamBold
    F.makeLabel(pg, "The game's own characters, animated: GF sways to the beat, BF sings what you press and the opponent sings when your RP opponent poses. On screen, or standing in the game where only you can see them.",
        UDim2.new(0,8,0,26), UDim2.new(1,-16,0,40), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 9).TextWrapped = true

    local oY = 70
    local toggles = {
        { tbl = Chars,  key = "enabled",   on = "STAGE: ON",       off = "STAGE: OFF" },
        { tbl = Chars,  key = "showOpp",   on = "OPPONENT: ON",    off = "OPPONENT: OFF" },
        { tbl = Arrows, key = "oppShow",   on = "OPP ARROWS: ON",  off = "OPP ARROWS: OFF" },
        { tbl = Chars,  key = "follow",    on = "FOLLOWS ME: ON",  off = "FOLLOWS ME: OFF" },
        { tbl = Chars,  key = "draggable", on = "DRAG STAGE: ON",  off = "DRAG STAGE: OFF" },
    }
    for i, t in ipairs(toggles) do
        local col = (i - 1) % 3
        local rowN = math.floor((i - 1) / 3)
        local b = F.makeBtn(pg, t.tbl[t.key] and t.on or t.off,
            UDim2.new(0, 8 + col * 132, 0, oY + rowN * 32), UDim2.new(0, 126, 0, 26),
            t.tbl[t.key] and Color3.fromRGB(60,190,120) or Color3.fromRGB(35,35,55), nil, 9)
        b.MouseButton1Click:Connect(function()
            t.tbl[t.key] = not t.tbl[t.key]
            b.Text = t.tbl[t.key] and t.on or t.off
            b.BackgroundColor3 = t.tbl[t.key] and Color3.fromRGB(60,190,120) or Color3.fromRGB(35,35,55)
            if t.key == "enabled" or t.key == "showOpp" then
                if not Chars.refresh(true) then
                    F.notify("No BF / GF frames in workspace/FNFInjector/sprites. Run tools/make_fnf_characters.py.", "warn")
                end
            end
            if t.key == "oppShow" then F.refreshOppStrip() end
        end)
    end

    -- where the stage is: drawn over your screen, or standing in the game
    local sY = oY + math.ceil(#toggles / 3) * 32 + 4
    local modeBtn = F.makeBtn(pg, "", UDim2.new(0,8,0,sY), UDim2.new(0,190,0,28),
        Color3.fromRGB(70,120,255), nil, 10)
    local placeBtn = F.makeBtn(pg, "PLACE STAGE HERE", UDim2.new(0,206,0,sY), UDim2.new(0,190,0,28),
        Color3.fromRGB(35,35,55), nil, 10)
    local function paintMode()
        modeBtn.Text = (Chars.mode == "WORLD") and "STAGE: IN THE GAME" or "STAGE: ON SCREEN"
    end
    paintMode()
    modeBtn.MouseButton1Click:Connect(function()
        Chars.mode = (Chars.mode == "WORLD") and "SCREEN" or "WORLD"
        paintMode()
        if Chars.wanted() then
            if not Chars.refresh(true) then
                F.notify("No BF / GF frames in workspace/FNFInjector/sprites. Run tools/make_fnf_characters.py.", "warn")
            end
        else
            F.notify("Turn the STAGE on to see them", "info")
        end
        if Chars.mode == "WORLD" then
            F.notify("In the game: they stand around where you are. Only you can see them.", "info")
        end
    end)
    placeBtn.MouseButton1Click:Connect(function()
        Chars.anchor = Chars.anchorFromMe()
        if Chars.world then Chars.placeWorld(false) end
        F.notify((Chars.mode == "WORLD") and "Stage moved to where you're standing"
            or "Set the stage to IN THE GAME first, then place it", "info")
    end)

    F.makeLabel(pg, "OPPONENT", UDim2.new(0,8,0,sY+34), UDim2.new(0,150,0,26),
        Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local oppBox = F.makeBox(pg, UDim2.new(0,160,0,sY+34), UDim2.new(1,-168,0,26),
        "dad, spooky, pico, tankman, tricky ...", Chars.freeOpp)
    oppBox.FocusLost:Connect(function()
        local id = string.gsub(oppBox.Text or "", "%s", "")
        if id == "" then id = "dad" end
        if not Chars.info(id) then
            F.notify("No baked character called \"" .. id .. "\". Names match the folders in sprites/chars.", "warn")
            oppBox.Text = Chars.freeOpp
            return
        end
        Chars.freeOpp = id
        oppBox.Text = id
        pcall(Chars.refresh, true)
    end)

    local sliders = {
        { label = "SIZE ON SCREEN", min = 0.4, max = 1.8, get = function() return Chars.scale end,
          set = function(v)
              Chars.scale = v
              if Chars.gui then pcall(Chars.refresh, true) end
          end },
        { label = "SIZE IN THE GAME", min = 0.4, max = 3, get = function() return Chars.worldScale end,
          set = function(v)
              Chars.worldScale = v
              if Chars.world then pcall(Chars.refresh, true) end
          end },
    }
    for i, sl in ipairs(sliders) do
        local ry = sY + 34 + 32 + 8 + (i - 1) * 42
        F.makeLabel(pg, sl.label, UDim2.new(0,8,0,ry), UDim2.new(0,280,0,18),
            Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
        local vlbl = F.makeLabel(pg, string.format("%.2fx", sl.get()), UDim2.new(0,306,0,ry), UDim2.new(0,90,0,18),
            Color3.fromRGB(255,80,180), Enum.TextXAlignment.Right, 10)
        F.regText(vlbl)
        F.makeSlider(pg, UDim2.new(0,8,0,ry+20), UDim2.new(1,-16,0,12), sl.min, sl.max, sl.get(), function(v)
            sl.set(v)
            vlbl.Text = string.format("%.2fx", v)
        end)
    end

    local count = 0
    for _ in pairs(Chars.load() or {}) do count = count + 1 end
    F.makeLabel(pg, count > 0 and string.format("%d characters baked. New mods? Run tools/make_fnf_characters.py again.", count)
            or "No characters baked yet: run tools/make_fnf_characters.py.",
        UDim2.new(0,8,0,sY + 34 + 32 + 8 + #sliders * 42 + 4), UDim2.new(1,-16,0,30),
        Color3.fromRGB(120,120,140), Enum.TextXAlignment.Left, 9).TextWrapped = true
end

function F.buildTab_Binds(pages)
    local pg1 = pages["📋 BINDS"]

    F.makeLabel(pg1, "DIR",     UDim2.new(0,8,0,6),   UDim2.new(0,36,0,20), Color3.fromRGB(255,80,180))
    F.makeLabel(pg1, "KEY",     UDim2.new(0,48,0,6),  UDim2.new(0,62,0,20), Color3.fromRGB(255,80,180))
    F.makeLabel(pg1, "ANIM ID", UDim2.new(0,116,0,6), UDim2.new(0,180,0,20),Color3.fromRGB(255,80,180))
    F.makeLabel(pg1, "TEST",    UDim2.new(0,308,0,6), UDim2.new(0,90,0,20), Color3.fromRGB(255,80,180))
    F.makeDivider(pg1, 28, Color3.fromRGB(0,200,255))

    local ROW_H  = 186
    local startY = 36
    for i, row in ipairs(CurrentBindings) do
        local y = startY + (i-1)*ROW_H
        local dirColor = ARROW_COLORS[row.dir] and ARROW_COLORS[row.dir].hit or Color3.fromRGB(255,255,255)
        F.makeLabel(pg1, row.dir, UDim2.new(0,8,0,y), UDim2.new(0,36,0,28), dirColor)

        local keyBtn = F.makeBtn(pg1, row.key, UDim2.new(0,48,0,y), UDim2.new(0,60,0,28), Color3.fromRGB(25,35,48))
        row.keyBtn = keyBtn
        keyBtn.MouseButton1Click:Connect(function()
            rebindingRow = row; keyBtn.Text = "..."
            keyBtn.BackgroundColor3 = Color3.fromRGB(0,200,255)
        end)

        local idBox = F.makeBox(pg1, UDim2.new(0,116,0,y), UDim2.new(0,180,0,28), "anim id", row.id)
        row.idBox = idBox
        idBox.FocusLost:Connect(function()
            local n = idBox.Text:gsub("%D","")
            if n ~= "" then
                row.id = n; F.destroyTrack(row.key)
                F.getTrack(n, row.holdLoop)       -- ready before the first press
            else
                idBox.Text = row.id
            end
        end)

        local testBtn = F.makeBtn(pg1, "▶ TEST", UDim2.new(0,306,0,y), UDim2.new(0,90,0,28), Color3.fromRGB(0,180,230), nil, 11)
        testBtn.MouseButton1Down:Connect(function()
            local chosenId = F.rollBindingAnimId(row)   -- follows the note's mode
            F.playAnim(row.key, chosenId, row.speedMult, row.holdLoop); F.hitArrow(row.dir); F.swapFace(row.dir)
        end)
        testBtn.MouseButton1Up:Connect(function()   F.stopAnim(row.key); F.releaseArrow(row.dir); F.restoreFace() end)

        local sy = y + 30
        F.makeLabel(pg1, "SPD", UDim2.new(0,8,0,sy), UDim2.new(0,32,0,22), Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
        local spdBox = F.makeBox(pg1, UDim2.new(0,42,0,sy), UDim2.new(0,120,0,22), "1.00", string.format("%.2f", row.speedMult))
        local spdValLbl = F.makeLabel(pg1, string.format("x%.2f", row.speedMult),
            UDim2.new(0,170,0,sy), UDim2.new(0,222,0,22), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Left, 10)
        F.regText(spdValLbl)
        spdBox.FocusLost:Connect(function()
            local n = tonumber(spdBox.Text)
            if n and n > 0 then
                row.speedMult = n
                spdValLbl.Text = string.format("x%.2f", n)
                if StatusState.currentAnimName == row.key then
                    StatusState.speedMult = n
                    if F.refreshStatusUI then F.refreshStatusUI() end
                end
            else
                spdBox.Text = string.format("%.2f", row.speedMult)
            end
        end)

        local sy2 = y + 58
        local holdBtn = F.makeBtn(pg1, row.holdLoop and "HOLD-LOOP: ON" or "HOLD-LOOP: OFF",
            UDim2.new(0,8,0,sy2), UDim2.new(0,126,0,24),
            row.holdLoop and Color3.fromRGB(0,180,230) or Color3.fromRGB(35,35,55), nil, 9)
        holdBtn.MouseButton1Click:Connect(function()
            row.holdLoop = not row.holdLoop
            holdBtn.Text = row.holdLoop and "HOLD-LOOP: ON" or "HOLD-LOOP: OFF"
            holdBtn.BackgroundColor3 = row.holdLoop and Color3.fromRGB(0,180,230) or Color3.fromRGB(35,35,55)
        end)

        -- how the note chooses between its animations
        local modeBtn = F.makeBtn(pg1, "MODE: " .. (row.mode or "CYCLE"),
            UDim2.new(0,140,0,sy2), UDim2.new(0,130,0,24), Color3.fromRGB(70,120,255), nil, 9)

        local addBtn = F.makeBtn(pg1, "+ ANIM", UDim2.new(0,276,0,sy2),
            UDim2.new(0,120,0,24), Color3.fromRGB(60,190,120), nil, 10)

        local sy3 = y + 88
        local altListFrame = Instance.new("ScrollingFrame")
        altListFrame.Size = UDim2.new(1,-16,0,88)
        altListFrame.Position = UDim2.new(0,8,0,sy3)
        altListFrame.BackgroundColor3 = Color3.fromRGB(12,11,18)
        altListFrame.BackgroundTransparency = 0.25
        altListFrame.BorderSizePixel = 0
        altListFrame.ScrollBarThickness = 3
        altListFrame.CanvasSize = UDim2.new(0,0,0,0)
        altListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
        altListFrame.Parent = pg1
        F.uiCorner(altListFrame, UDim.new(0,6))
        local altListLayout = Instance.new("UIListLayout")
        altListLayout.Padding = UDim.new(0,3)
        altListLayout.SortOrder = Enum.SortOrder.LayoutOrder
        altListLayout.Parent = altListFrame
        local altListPad = Instance.new("UIPadding")
        altListPad.PaddingTop = UDim.new(0,3); altListPad.PaddingLeft = UDim.new(0,3)
        altListPad.PaddingRight = UDim.new(0,3)
        altListPad.Parent = altListFrame

        local modeOrder = { "CYCLE", "RANDOM", "WEIGHTED" }
        modeBtn.MouseButton1Click:Connect(function()
            local idx = table.find(modeOrder, row.mode or "CYCLE") or 1
            row.mode = modeOrder[(idx % #modeOrder) + 1]
            row.cycleIdx = 0
            modeBtn.Text = "MODE: " .. row.mode
            F.refreshRowAltList(row, altListFrame)
            F.notify(row.dir .. ": " .. ({
                CYCLE = "plays each animation in order",
                RANDOM = "picks one at random",
                WEIGHTED = "uses the % chances",
            })[row.mode], "info")
        end)

        addBtn.MouseButton1Click:Connect(function()
            if #row.alts >= 12 then F.notify("12 extra animations is the limit per note", "warn"); return end
            table.insert(row.alts, { id = "", chance = 0 })
            F.refreshRowAltList(row, altListFrame)
            -- jump to the new box so you can paste straight in
            task.defer(function()
                altListFrame.CanvasPosition = Vector2.new(0, math.max(0, altListFrame.AbsoluteCanvasSize.Y))
            end)
        end)

        F.refreshRowAltList(row, altListFrame)
    end

    -- ── POSE RESPONSE ──
    local prY = startY + #CurrentBindings * ROW_H + 6
    F.makeDivider(pg1, prY, Color3.fromRGB(0,200,255))
    local prTitle = F.makeLabel(pg1, "POSE RESPONSE", UDim2.new(0,8,0,prY+6),
        UDim2.new(0,200,0,20), Color3.fromRGB(0,200,255), Enum.TextXAlignment.Left, 12)
    prTitle.Font = Enum.Font.GothamBold
    F.makeLabel(pg1, "How fast a pose lands when you press. Lower is snappier.",
        UDim2.new(0,8,0,prY+26), UDim2.new(1,-16,0,16), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 9)

    local prSnap = F.makeBtn(pg1, Pose.snap and "SNAP: ON" or "SNAP: OFF",
        UDim2.new(0,8,0,prY+46), UDim2.new(0,126,0,26),
        Pose.snap and Color3.fromRGB(255,160,40) or Color3.fromRGB(35,35,55), nil, 9)
    prSnap.MouseButton1Click:Connect(function()
        Pose.snap = not Pose.snap
        prSnap.Text = Pose.snap and "SNAP: ON" or "SNAP: OFF"
        prSnap.BackgroundColor3 = Pose.snap and Color3.fromRGB(255,160,40) or Color3.fromRGB(35,35,55)
    end)
    F.makeLabel(pg1, "Skip the motion and land on the pose that frame.",
        UDim2.new(0,142,0,prY+46), UDim2.new(1,-150,0,26), Color3.fromRGB(120,120,140), Enum.TextXAlignment.Left, 9)

    F.makeLabel(pg1, "REACH TIME", UDim2.new(0,8,0,prY+80), UDim2.new(0,200,0,18),
        Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local prLbl = F.makeLabel(pg1, string.format("%.3fs", Pose.reach),
        UDim2.new(0,306,0,prY+80), UDim2.new(0,90,0,18), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Right, 10)
    F.regText(prLbl)
    F.makeSlider(pg1, UDim2.new(0,8,0,prY+100), UDim2.new(1,-16,0,12), 0.01, 0.3, Pose.reach, function(v)
        Pose.reach = v
        prLbl.Text = string.format("%.3fs", v)
    end)

    -- ── DODGE: just an animation on a key ──
    local dgY = prY + 124
    F.makeDivider(pg1, dgY, Color3.fromRGB(80,220,255))
    local dgTitle = F.makeLabel(pg1, "DODGE", UDim2.new(0,8,0,dgY+6),
        UDim2.new(0,200,0,20), Color3.fromRGB(80,220,255), Enum.TextXAlignment.Left, 12)
    dgTitle.Font = Enum.Font.GothamBold

    local dgKey = F.makeBtn(pg1, Pose.dodgeKey, UDim2.new(0,8,0,dgY+30),
        UDim2.new(0,70,0,28), Color3.fromRGB(25,35,48), nil, 11)
    dgKey.MouseButton1Click:Connect(function()
        dgKey.Text = "..."; dgKey.BackgroundColor3 = Color3.fromRGB(0,200,255)
        local conn; conn = F.own(UserInputService.InputBegan:Connect(function(inp)
            if inp.KeyCode and inp.KeyCode.Name ~= "Unknown" and not inp.KeyCode.Name:match("Mouse") then
                Pose.dodgeKey = inp.KeyCode.Name
                dgKey.Text = Pose.dodgeKey
                dgKey.BackgroundColor3 = Color3.fromRGB(25,35,48)
                if Keys.refresh then Keys.refresh() end
                conn:Disconnect()
            end
        end))
    end)

    local dgId = F.makeBox(pg1, UDim2.new(0,84,0,dgY+30), UDim2.new(0,218,0,28), "dodge animation ID", Pose.dodgeId)
    dgId.FocusLost:Connect(function()
        Pose.dodgeId = (dgId.Text:gsub("%D",""))
        dgId.Text = Pose.dodgeId
        if Pose.dodgeId ~= "" then F.getTrack(Pose.dodgeId, false) end
    end)

    local dgTest = F.makeBtn(pg1, "TEST", UDim2.new(0,308,0,dgY+30),
        UDim2.new(0,88,0,28), Color3.fromRGB(0,180,230), nil, 10)
    dgTest.MouseButton1Click:Connect(function()
        if Pose.dodgeId == "" then F.notify("Paste a dodge animation ID first", "warn"); return end
        F.playDodge()
    end)

    -- ── POSE HOLD (sits right under the pose binds) ──
    local hdY = dgY + 70
    F.makeDivider(pg1, hdY, Color3.fromRGB(255,160,40))
    local hdTitle = F.makeLabel(pg1, "POSE HOLD", UDim2.new(0,8,0,hdY+6),
        UDim2.new(0,160,0,20), Color3.fromRGB(255,160,40), Enum.TextXAlignment.Left, 12)
    hdTitle.Font = Enum.Font.GothamBold
    F.makeLabel(pg1, "Short poses stay frozen after you let go. Your next note or any emote breaks it; idle and walking don't.",
        UDim2.new(0,8,0,hdY+26), UDim2.new(1,-16,0,28), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 9)

    local function hdToggle(x, key, on, off)
        local b = F.makeBtn(pg1, Hold[key] and on or off, UDim2.new(0,x,0,hdY+58),
            UDim2.new(0,126,0,26), Hold[key] and Color3.fromRGB(255,160,40) or Color3.fromRGB(35,35,55), nil, 9)
        b.MouseButton1Click:Connect(function()
            Hold[key] = not Hold[key]
            b.Text = Hold[key] and on or off
            b.BackgroundColor3 = Hold[key] and Color3.fromRGB(255,160,40) or Color3.fromRGB(35,35,55)
            if key == "enabled" and not Hold.enabled then Hold.clear(true) end
        end)
    end
    hdToggle(8,   "enabled", "HOLD: ON",      "HOLD: OFF")
    hdToggle(140, "holdAll", "HOLD ALL: ON",  "HOLD ALL: OFF")
    hdToggle(272, "cutter",  "CUTTER: ON",    "CUTTER: OFF")

    local unBtn = F.makeBtn(pg1, Hold.untilNext and "UNTIL NEXT POSE: ON" or "UNTIL NEXT POSE: OFF",
        UDim2.new(0,8,0,hdY+88), UDim2.new(0,190,0,26),
        Hold.untilNext and Color3.fromRGB(255,160,40) or Color3.fromRGB(35,35,55), nil, 9)
    unBtn.MouseButton1Click:Connect(function()
        Hold.untilNext = not Hold.untilNext
        unBtn.Text = Hold.untilNext and "UNTIL NEXT POSE: ON" or "UNTIL NEXT POSE: OFF"
        unBtn.BackgroundColor3 = Hold.untilNext and Color3.fromRGB(255,160,40) or Color3.fromRGB(35,35,55)
    end)
    F.makeLabel(pg1, "Never times out — stays posed until the next one.",
        UDim2.new(0,206,0,hdY+88), UDim2.new(1,-214,0,26), Color3.fromRGB(120,120,140), Enum.TextXAlignment.Left, 9)

    local hdRows = {
        { key = "duration", label = "HOLD TIME (s)",        min = 0.5, max = 15, fmt = "%.1f" },
        { key = "shortAt",  label = "COUNTS AS SHORT UNDER (s)", min = 0.1, max = 5,  fmt = "%.2f" },
        { key = "fadeOut",  label = "RELEASE BLEND (s)",    min = 0,   max = 1,  fmt = "%.2f" },
    }
    for i, row in ipairs(hdRows) do
        local ry = hdY + 122 + (i-1) * 40
        F.makeLabel(pg1, row.label, UDim2.new(0,8,0,ry), UDim2.new(0,240,0,18),
            Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 9)
        local vlbl = F.makeLabel(pg1, string.format(row.fmt, Hold[row.key]),
            UDim2.new(0,306,0,ry), UDim2.new(0,90,0,18), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Right, 9)
        F.regText(vlbl)
        local ck, cfm = row.key, row.fmt
        F.makeSlider(pg1, UDim2.new(0,8,0,ry+20), UDim2.new(1,-16,0,12),
            row.min, row.max, Hold[row.key], function(v)
                Hold[ck] = v
                vlbl.Text = string.format(cfm, v)
            end)
    end

    local hdStatus = F.makeLabel(pg1, "", UDim2.new(0,8,0,hdY + 122 + #hdRows * 40 + 2),
        UDim2.new(1,-16,0,18), Color3.fromRGB(160,160,180), Enum.TextXAlignment.Left, 10)
    task.spawn(function()
        while F.alive do
            task.wait(0.1)
            if not hdStatus.Parent then break end
            if Hold.track then
                hdStatus.Text = Hold.untilNext
                    and string.format("HOLDING %s  —  until next pose", tostring(Hold.label))
                    or string.format("HOLDING %s  —  %.1fs left", tostring(Hold.label), Hold.remaining())
                hdStatus.TextColor3 = Color3.fromRGB(255,160,40)
            else
                hdStatus.Text = Hold.enabled and "ready" or "off"
                hdStatus.TextColor3 = Color3.fromRGB(130,130,150)
            end
        end
    end)

    -- SOLO MODE SECTION
    local soloY = hdY + 122 + #hdRows * 40 + 30
    F.makeDivider(pg1, soloY, Color3.fromRGB(255,200,60))
    local soloTitle = F.makeLabel(pg1, "🎤 SOLO MODE", UDim2.new(0,8,0,soloY+6), UDim2.new(0,140,0,20),
        Color3.fromRGB(255,200,60), Enum.TextXAlignment.Left, 12)
    soloTitle.Font = Enum.Font.GothamBold
    F.makeLabel(pg1, "Camera zooms in tight on you with cinematic bars. Press the key to toggle.",
        UDim2.new(0,8,0,soloY+26), UDim2.new(1,-16,0,16), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 9)

    F.makeLabel(pg1, "KEY", UDim2.new(0,8,0,soloY+48), UDim2.new(0,30,0,24), Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local soloKeyBtn = F.makeBtn(pg1, soloKey, UDim2.new(0,42,0,soloY+48), UDim2.new(0,60,0,24), Color3.fromRGB(25,35,48), nil, 11)
    soloKeyBtn.MouseButton1Click:Connect(function()
        soloKeyBtn.Text = "..."
        soloKeyBtn.BackgroundColor3 = Color3.fromRGB(0,200,255)
        local conn; conn = F.own(UserInputService.InputBegan:Connect(function(inp)
            if inp.KeyCode and inp.KeyCode.Name ~= "Unknown" and not inp.KeyCode.Name:match("Mouse") then
                soloKey = inp.KeyCode.Name
                soloKeyBtn.Text = soloKey
                soloKeyBtn.BackgroundColor3 = Color3.fromRGB(25,35,48)
                conn:Disconnect()
            end
        end))
    end)

    local soloStatusLbl = F.makeLabel(pg1, soloActive and "🎤 SOLO ACTIVE" or "● OFF",
        UDim2.new(0,114,0,soloY+48), UDim2.new(0,120,0,24),
        soloActive and Color3.fromRGB(255,200,60) or Color3.fromRGB(160,80,80), Enum.TextXAlignment.Left, 10)

    F.makeLabel(pg1, "ZOOM", UDim2.new(0,240,0,soloY+48), UDim2.new(0,40,0,24), Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 9)
    F.makeSlider(pg1, UDim2.new(0,280,0,soloY+50), UDim2.new(0,112,0,12), 3, 12, soloCamDist, function(v)
        soloCamDist = v
    end)

    task.spawn(function()
        while F.alive do
            task.wait(0.2)
            if soloStatusLbl and soloStatusLbl.Parent then
                soloStatusLbl.Text = soloActive and "🎤 SOLO ACTIVE" or "● OFF"
                soloStatusLbl.TextColor3 = soloActive and Color3.fromRGB(255,200,60) or Color3.fromRGB(160,80,80)
            end
        end
    end)

    local idleY = soloY + 80
    F.makeDivider(pg1, idleY, Color3.fromRGB(255,80,180))
    local idleTitleLbl = F.makeLabel(pg1, "🎵 IDLE ANIMATION",
        UDim2.new(0,8,0,idleY+6), UDim2.new(0,200,0,20),
        Color3.fromRGB(255,80,180), Enum.TextXAlignment.Left)
    F.regText(idleTitleLbl)
    local statusLbl = F.makeLabel(pg1, "● OFF",
        UDim2.new(0,200,0,idleY+6), UDim2.new(0,196,0,20),
        Color3.fromRGB(160,80,80), Enum.TextXAlignment.Right)

    local idleIdBox = F.makeBox(pg1, UDim2.new(0,8,0,idleY+30), UDim2.new(1,-16,0,28), "Paste idle anim ID...", Idle.id)
    local loopBtn  = F.makeBtn(pg1, "⟳ LOOP",  UDim2.new(0,8,0,idleY+64), UDim2.new(0,120,0,28), Color3.fromRGB(70,120,255))
    local onceBtn  = F.makeBtn(pg1, "▶ ONCE",  UDim2.new(0,136,0,idleY+64), UDim2.new(0,120,0,28), Color3.fromRGB(60,190,120))
    local idleStop = F.makeBtn(pg1, "■ STOP",  UDim2.new(0,264,0,idleY+64), UDim2.new(0,130,0,28), Color3.fromRGB(190,50,50))
    Idle.box, Idle.statusLbl = idleIdBox, statusLbl
    if Idle.auto and Idle.id ~= "" then Idle.paintStatus("LOOP") end

    -- the ID in the box is part of your save; LOOP also brings it back
    -- when you load and every time you respawn, until you press STOP
    local function getIdleId() return (idleIdBox.Text:gsub("%D","")) end
    idleIdBox.FocusLost:Connect(function()
        Idle.id = getIdleId()
        idleIdBox.Text = Idle.id
    end)
    loopBtn.MouseButton1Click:Connect(function()
        local id = getIdleId(); if id == "" then F.notify("Enter an idle anim ID first", "warn"); return end
        Idle.id, Idle.auto = id, true
        F.playIdleLoop(id); Idle.paintStatus("LOOP")
        F.notify("Idle looping — it comes back when you load or respawn", "success")
    end)
    onceBtn.MouseButton1Click:Connect(function()
        local id = getIdleId(); if id == "" then F.notify("Enter an idle anim ID first", "warn"); return end
        Idle.id = id
        F.playIdleOnce(id, function()
            if not idleLooping then Idle.paintStatus("OFF") end
        end)
        Idle.paintStatus("ONCE")
    end)
    idleStop.MouseButton1Click:Connect(function()
        Idle.auto = false
        F.stopIdle(); Idle.paintStatus("OFF")
    end)

    -- your idle list
    local svY = idleY + 100
    local idleName = F.makeBox(pg1, UDim2.new(0,8,0,svY), UDim2.new(0,250,0,26), "name it, then SAVE IDLE")
    local idleSave = F.makeBtn(pg1, "+ SAVE IDLE", UDim2.new(0,264,0,svY), UDim2.new(0,130,0,26),
        Color3.fromRGB(60,190,120), nil, 10)
    local idleList = Instance.new("ScrollingFrame")
    idleList.Size = UDim2.new(1,-16,0,104); idleList.Position = UDim2.new(0,8,0,svY+32)
    idleList.BackgroundColor3 = Color3.fromRGB(18,18,26); idleList.BackgroundTransparency = 0.2
    idleList.BorderSizePixel = 0; idleList.ScrollBarThickness = 3
    idleList.CanvasSize = UDim2.new(0,0,0,0); idleList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    idleList.Parent = pg1
    F.uiCorner(idleList)
    local idleLay = Instance.new("UIListLayout")
    idleLay.Padding = UDim.new(0,3); idleLay.SortOrder = Enum.SortOrder.LayoutOrder; idleLay.Parent = idleList
    local idlePad = Instance.new("UIPadding")
    idlePad.PaddingTop = UDim.new(0,4); idlePad.PaddingLeft = UDim.new(0,4); idlePad.PaddingRight = UDim.new(0,4)
    idlePad.Parent = idleList
    Idle.listFrame = idleList
    idleSave.MouseButton1Click:Connect(function()
        Idle.saveCurrent(idleName.Text, getIdleId())
        idleName.Text = ""
    end)
    Idle.redraw()

    local bpmY = svY + 144
    F.makeLabel(pg1, "BPM", UDim2.new(0,8,0,bpmY), UDim2.new(0,38,0,28),
        Color3.fromRGB(255,80,180), Enum.TextXAlignment.Left, 11)
    local bpmBox = F.makeBox(pg1, UDim2.new(0,44,0,bpmY), UDim2.new(0,68,0,28), "100", tostring(idleBPM))

    F.makeLabel(pg1, "BASE", UDim2.new(0,120,0,bpmY), UDim2.new(0,44,0,28),
        Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local baseBox = F.makeBox(pg1, UDim2.new(0,164,0,bpmY), UDim2.new(0,68,0,28), "100", tostring(BASE_BPM))

    local applyBpmBtn = F.makeBtn(pg1, "✓ APPLY", UDim2.new(0,240,0,bpmY), UDim2.new(0,154,0,28), Color3.fromRGB(70,120,255), nil, 11)

    local bpmSliderY = bpmY + 36
    F.makeLabel(pg1, "DRAG", UDim2.new(0,8,0,bpmSliderY), UDim2.new(0,50,0,22), Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local bpmValLbl = F.makeLabel(pg1, string.format("%d BPM", idleBPM),
        UDim2.new(0,300,0,bpmSliderY), UDim2.new(0,94,0,22), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Right, 11)
    F.regText(bpmValLbl)
    local bpmSlider = F.makeSlider(pg1, UDim2.new(0,62,0,bpmSliderY+2), UDim2.new(0,232,0,14), 40, 300, idleBPM, function(v)
        v = math.floor(v + 0.5)
        F.setIdleBPM(v)
        bpmBox.Text = tostring(v)
        bpmValLbl.Text = string.format("%d BPM", v)
    end)

    bpmBox.FocusLost:Connect(function()
        local n = tonumber(bpmBox.Text)
        if n and n > 0 then
            idleBPM = n
            bpmSlider.setValue(n, false)
            bpmValLbl.Text = string.format("%d BPM", n)
            F.setIdleBPM(n)
        else
            bpmBox.Text = tostring(idleBPM)
        end
    end)
    baseBox.FocusLost:Connect(function()
        local n = tonumber(baseBox.Text)
        if n and n > 0 then BASE_BPM = n else baseBox.Text = tostring(BASE_BPM) end
        F.setIdleBPM(idleBPM)
    end)
    applyBpmBtn.MouseButton1Click:Connect(function()
        local n = tonumber(bpmBox.Text)
        local b = tonumber(baseBox.Text)
        if n and n > 0 then idleBPM = n; bpmSlider.setValue(n, false); bpmValLbl.Text = string.format("%d BPM", n) end
        if b and b > 0 then BASE_BPM = b end
        F.setIdleBPM(idleBPM)
        F.notify("BPM settings applied", "info")
    end)
    Idle.syncBpmUI = function()
        bpmBox.Text = tostring(idleBPM)
        baseBox.Text = tostring(BASE_BPM)
        bpmSlider.setValue(idleBPM, false)
        bpmValLbl.Text = string.format("%d BPM", math.floor(idleBPM + 0.5))
    end

    local vizY = bpmSliderY + 34
    F.makeDivider(pg1, vizY, Color3.fromRGB(0,200,255))
    F.makeLabel(pg1, "BEAT SYNC", UDim2.new(0,8,0,vizY+6), UDim2.new(0,90,0,18), Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    beatDot = Instance.new("Frame")
    beatDot.AnchorPoint = Vector2.new(0.5,0.5)
    beatDot.Size = UDim2.new(0,10,0,10)
    beatDot.Position = UDim2.new(0,100,0,vizY+15)
    beatDot.BackgroundColor3 = Color3.fromRGB(255,80,180)
    beatDot.BorderSizePixel = 0; beatDot.Parent = pg1
    F.uiCorner(beatDot, UDim.new(1,0))
    F.regBg(beatDot)

    F.makeLabel(pg1, "EQUALIZER", UDim2.new(0,140,0,vizY+6), UDim2.new(0,100,0,18), Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local eqHolder = Instance.new("Frame")
    eqHolder.Size = UDim2.new(0,120,0,26); eqHolder.Position = UDim2.new(0,140,0,vizY+22)
    eqHolder.BackgroundTransparency = 1; eqHolder.Parent = pg1
    local eqLayout = Instance.new("UIListLayout")
    eqLayout.FillDirection = Enum.FillDirection.Horizontal
    eqLayout.Padding = UDim.new(0,3)
    eqLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    eqLayout.Parent = eqHolder
    eqBars = {}
    for i = 1, 8 do
        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(0, 10, 0.2, 0)
        bar.BackgroundColor3 = THEMES[currentThemeName].accent
        bar.BorderSizePixel = 0
        bar.Parent = eqHolder
        F.uiCorner(bar, UDim.new(0,2))
        F.regBg(bar)
        table.insert(eqBars, bar)
    end

    F.makeLabel(pg1, "WAVEFORM", UDim2.new(0,270,0,vizY+6), UDim2.new(0,120,0,18), Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local waveHolder = Instance.new("Frame")
    waveHolder.Size = UDim2.new(0,130,0,26); waveHolder.Position = UDim2.new(0,270,0,vizY+22)
    waveHolder.BackgroundTransparency = 1; waveHolder.Parent = pg1
    local waveLayout = Instance.new("UIListLayout")
    waveLayout.FillDirection = Enum.FillDirection.Horizontal
    waveLayout.Padding = UDim.new(0,2)
    waveLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    waveLayout.Parent = waveHolder
    waveBars = {}
    for i = 1, 16 do
        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(0, 5, 0.3, 0)
        bar.BackgroundColor3 = THEMES[currentThemeName].accent2
        bar.BorderSizePixel = 0
        bar.Parent = waveHolder
        F.uiCorner(bar, UDim.new(0,2))
        table.insert(waveBars, bar)
    end

    local statusY = vizY + 60
    F.makeDivider(pg1, statusY, Color3.fromRGB(255,80,180))
    local statusTitle = F.makeLabel(pg1, "📊 STATUS", UDim2.new(0,8,0,statusY+6), UDim2.new(0,120,0,18), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Left, 11)
    F.regText(statusTitle)

    local statLbl1 = F.makeLabel(pg1, "Anim: —", UDim2.new(0,8,0,statusY+26), UDim2.new(1,-16,0,16), Color3.fromRGB(210,210,220), Enum.TextXAlignment.Left, 10)
    local statLbl2 = F.makeLabel(pg1, "Speed: x1.00   BPM: 100   State: STOPPED", UDim2.new(0,8,0,statusY+44), UDim2.new(1,-16,0,16), Color3.fromRGB(160,160,180), Enum.TextXAlignment.Left, 10)

    F.refreshStatusUI = function()
        statLbl1.Text = string.format("Anim: %s (%s)", StatusState.currentAnimName, StatusState.currentAnimId ~= "" and StatusState.currentAnimId or "—")
        statLbl2.Text = string.format("Speed: x%.2f   BPM: %d   State: %s",
            StatusState.speedMult, StatusState.bpm, StatusState.playing and "PLAYING" or "STOPPED")
    end
    F.refreshStatusUI()

end

-- ============================================================
--  CUTTER TAB
--  Load an animation, scrub it frame by frame in a live preview,
--  then mark a start and stop for each direction straight from
--  the playhead. The timeline stretches to the animation's real
--  length, so every number on it is a real time in the clip.
-- ============================================================
function Cut.fmt(t) return string.format("%.2fs", t or 0) end

function Cut.buildClone()
    if not Cut.wm then return end
    if Cut.clone then pcall(function() Cut.clone:Destroy() end) end
    Cut.clone, Cut.animator, Cut.track = nil, nil, nil
    Cut.length, Cut.playhead = 0, 0

    local char = character
    if not char then return end
    local wasArch = char.Archivable
    if not wasArch then char.Archivable = true end
    local ok, clone = pcall(function() return char:Clone() end)
    if not wasArch then char.Archivable = wasArch end
    if not ok or not clone then return end

    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end
    end
    local hum = clone:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function() hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end)
        pcall(function() hum.RequiresNeck = false end)
        pcall(function() hum.BreakJointsOnDeath = false end)
        pcall(function() hum.EvaluateStateMachine = false end)
        Cut.animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
    end
    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("BasePart") then d.CanCollide = false; d.Massless = true; d.Anchored = false end
    end
    local root = clone:FindFirstChild("HumanoidRootPart") or clone.PrimaryPart
    if root then root.Anchored = true; clone.PrimaryPart = root end
    clone.Name = "CutterClone"
    clone.Parent = Cut.wm
    pcall(function() clone:PivotTo(CFrame.new(0, 3, 0) * CFrame.Angles(0, math.rad(Cut.yaw), 0)) end)
    Cut.clone = clone
end

-- Put the clone on an exact time in the clip and freeze it there.
function Cut.seek(t)
    Cut.playhead = math.clamp(t or 0, 0, math.max(Cut.length, 0))
    local tr = Cut.track
    if tr then
        if not tr.IsPlaying then tr:Play(0) end
        tr:AdjustSpeed(0)
        tr.TimePosition = math.min(Cut.playhead, math.max(Cut.length - 0.001, 0))
    end
    Cut.drawHead()
end

function Cut.drawHead()
    if Cut.head and Cut.length > 0 then
        Cut.head.Position = UDim2.new(Cut.playhead / Cut.length, -1, 0, -4)
    end
    if Cut.timeLbl then
        Cut.timeLbl.Text = Cut.fmt(Cut.playhead) .. "  /  " .. Cut.fmt(Cut.length)
    end
    if Cut.frameLbl then
        Cut.frameLbl.Text = string.format("frame %d / %d",
            math.floor(Cut.playhead * Cut.fps + 0.5), math.floor(Cut.length * Cut.fps + 0.5))
    end
end

-- Coloured regions on the timeline for each direction's slice.
function Cut.drawSlices()
    if Cut.length <= 0 then
        for _, f in pairs(Cut.sliceFrames) do f.Visible = false end
        return
    end
    for i, dir in ipairs(ARROW_ORDER) do
        local f = Cut.sliceFrames[dir]
        local s = cutterSlices[dir]
        local sid = (s and s.id ~= "" and s.id) or cutterAnimId
        if f and s and sid ~= Cut.editId then
            f.Visible = false
        elseif f and s then
            local a = math.clamp(s.start / Cut.length, 0, 1)
            local b = math.clamp(s.stop / Cut.length, 0, 1)
            if b < a then a, b = b, a end
            f.Visible = true
            f.Position = UDim2.new(a, 0, (i - 1) / 4, 0)
            f.Size = UDim2.new(math.max(b - a, 0.004), 0, 0.25, 0)
            f.BackgroundTransparency = (dir == Cut.selDir) and 0.05 or 0.45
        end
        if Cut.startBoxes[dir] then Cut.startBoxes[dir].Text = string.format("%.2f", s.start) end
        if Cut.stopBoxes[dir] then Cut.stopBoxes[dir].Text = string.format("%.2f", s.stop) end
    end
end

function Cut.loadAnim(id)
    if not id or id == "" then F.notify("Enter an animation ID", "warn"); return end
    if not Cut.clone then Cut.buildClone() end
    if not Cut.animator then F.notify("Preview rig unavailable", "error"); return end

    if Cut.track then pcall(function() Cut.track:Stop(0) end) end
    local ok, tr = pcall(function()
        local a = Instance.new("Animation")
        a.AnimationId = "rbxassetid://" .. id
        local t = Cut.animator:LoadAnimation(a)
        t.Priority = Enum.AnimationPriority.Action
        t.Looped = true
        return t
    end)
    if not ok or not tr then F.notify("Failed to load animation", "error"); return end
    Cut.track = tr
    tr:Play(0); tr:AdjustSpeed(0)
    if Cut.statusLbl then Cut.statusLbl.Text = "loading..." end

    -- Length is 0 until the asset streams in, so poll for it
    task.spawn(function()
        local deadline = os.clock() + 4
        while tr == Cut.track and tr.Length <= 0 and os.clock() < deadline do
            task.wait(0.05)
        end
        if tr ~= Cut.track then return end
        if tr.Length <= 0 then
            if Cut.statusLbl then Cut.statusLbl.Text = "couldn't read length — asset private or blocked?" end
            F.notify("Couldn't read the animation length", "error")
            return
        end
        Cut.length = tr.Length
        -- clamp only the slices cut from THIS animation into its length
        for _, dir in ipairs(ARROW_ORDER) do
            local s = cutterSlices[dir]
            local sid = (s.id ~= "" and s.id) or cutterAnimId
            if sid == id then
                s.start = math.clamp(s.start, 0, Cut.length)
                s.stop = math.clamp(s.stop, 0, Cut.length)
            end
        end
        if Cut.lenLbl then Cut.lenLbl.Text = "LENGTH " .. Cut.fmt(Cut.length) end
        if Cut.statusLbl then Cut.statusLbl.Text = "ready — drag the timeline to scrub" end
        Cut.seek(0)
        Cut.drawSlices()
        -- warm the gameplay track for this source so the first press is instant
        F.cutterTrackFor(id)
        F.notify("Loaded — " .. Cut.fmt(Cut.length), "success")
    end)
end

-- Show a note's animation in the preview. Only reloads when the animation
-- actually differs, so flicking between notes that share one is instant.
function Cut.editDir(dir, force)
    Cut.selDir = dir
    -- rig gone (respawn, or the tab was opened before the character loaded)
    if Cut.wm and (not Cut.clone or not Cut.clone.Parent or not Cut.animator) then
        Cut.buildClone()
        force = true
    end
    local id = F.cutterSliceId(dir)
    if not id or id == "" then
        if Cut.statusLbl then Cut.statusLbl.Text = dir .. " has no animation yet — type an ID for it" end
        return
    end
    if force or id ~= Cut.editId or not Cut.track then
        Cut.editId = id
        Cut.setPlaying(false)
        Cut.loadAnim(id)
    else
        Cut.drawSlices()
    end
end

function Cut.setPlaying(state)
    Cut.playing = state and Cut.length > 0
    if Cut.playBtn then
        Cut.playBtn.Text = Cut.playing and "PAUSE" or "PLAY"
        Cut.playBtn.BackgroundColor3 = Cut.playing and Color3.fromRGB(255,160,40) or Color3.fromRGB(60,190,120)
    end
end

function Cut.startLoop()
    if Cut.conn then return end
    Cut.conn = F.own(RunService.RenderStepped:Connect(function(dt)
        if not Cut.vp or not Cut.vp.Parent then return end
        if Cut.playing and Cut.length > 0 then
            local lo, hi = 0, Cut.length
            if Cut.loopSlice then
                local s = cutterSlices[Cut.selDir]
                lo, hi = math.min(s.start, s.stop), math.max(s.start, s.stop)
                if hi - lo < 0.01 then lo, hi = 0, Cut.length end
            end
            local t = Cut.playhead + dt
            if t > hi or t < lo then t = lo end
            Cut.seek(t)
        end
    end))
end

function F.buildTab_Cutter(pages)
    local pg = pages["✂ CUTTER"]
    local C = Color3.fromRGB

    local title = F.makeLabel(pg, "EMOTE CUTTER", UDim2.new(0,8,0,6),
        UDim2.new(0,200,0,22), C(255,80,180), Enum.TextXAlignment.Left, 14)
    title.Font = Enum.Font.GothamBlack
    F.regText(title)
    F.makeLabel(pg, "Give each note its own animation, scrub it, and cut its pose.",
        UDim2.new(0,8,0,28), UDim2.new(1,-150,0,16), C(130,130,150), Enum.TextXAlignment.Left, 9)

    local enBtn = F.makeBtn(pg, cutterEnabled and "CUTTER ON" or "CUTTER OFF",
        UDim2.new(1,-138,0,8), UDim2.new(0,130,0,30),
        cutterEnabled and THEMES[currentThemeName].accent or C(35,35,55), nil, 10)
    enBtn.MouseButton1Click:Connect(function()
        cutterEnabled = not cutterEnabled
        enBtn.Text = cutterEnabled and "CUTTER ON" or "CUTTER OFF"
        enBtn.BackgroundColor3 = cutterEnabled and THEMES[currentThemeName].accent or C(35,35,55)
        if cutterEnabled then F.cutterLoadTrack() else F.cutterStopSlice() end
        F.notify(cutterEnabled and "Cutter on — notes play your slices" or "Cutter off — normal binds", "info")
    end)

    -- ── default animation, for any note left blank ──
    local defBox = F.makeBox(pg, UDim2.new(0,8,0,52), UDim2.new(1,-114,0,30),
        "Default animation ID (any note left blank uses this)", cutterAnimId)
    local defLoad = F.makeBtn(pg, "LOAD", UDim2.new(1,-100,0,52), UDim2.new(0,92,0,30),
        C(70,120,255), nil, 11)
    local function commitDefault()
        cutterAnimId = (defBox.Text:gsub("%D",""))
        defBox.Text = cutterAnimId
        if cutterAnimId ~= "" then F.cutterTrackFor(cutterAnimId) end
        -- only reload if the note on screen actually uses the default
        local s = cutterSlices[Cut.selDir]
        if s and (s.id == nil or s.id == "") then Cut.editDir(Cut.selDir, true) end
        if Cut.refreshIdBoxes then Cut.refreshIdBoxes() end
    end
    defLoad.MouseButton1Click:Connect(commitDefault)
    defBox.FocusLost:Connect(function() commitDefault() end)

    -- ── preview viewport ──
    local vp = Instance.new("ViewportFrame")
    vp.Size = UDim2.new(1,-16,0,230); vp.Position = UDim2.new(0,8,0,90)
    vp.BackgroundColor3 = C(8,8,12)
    vp.Ambient = C(150,150,160); vp.LightColor = C(255,255,255)
    vp.LightDirection = Vector3.new(-0.5,-1,-0.4)
    vp.Parent = pg
    F.uiCorner(vp, UDim.new(0,10))
    local vpStroke = F.uiStroke(vp, THEMES[currentThemeName].accent, 1.5)
    F.regStroke(vpStroke)
    Cut.vp = vp

    local wm = Instance.new("WorldModel"); wm.Parent = vp
    local cam = Instance.new("Camera"); cam.FieldOfView = 50; cam.Parent = vp
    cam.CFrame = CFrame.new(Vector3.new(0, 3.3, 7.2), Vector3.new(0, 2.7, 0))
    vp.CurrentCamera = cam
    Cut.wm, Cut.cam = wm, cam

    local floor = F.own(Instance.new("Part"))
    floor.Size = Vector3.new(10,1,10); floor.Anchored = true; floor.CanCollide = false
    floor.Color = C(22,20,30); floor.Material = Enum.Material.SmoothPlastic
    floor.CFrame = CFrame.new(0,-0.5,0); floor.Parent = wm

    Cut.lenLbl = F.makeLabel(vp, "LENGTH --", UDim2.new(0,10,0,8), UDim2.new(0,220,0,16),
        C(235,235,245), Enum.TextXAlignment.Left, 10)
    Cut.lenLbl.Font = Enum.Font.GothamBold
    Cut.frameLbl = F.makeLabel(vp, "frame 0 / 0", UDim2.new(1,-150,0,8), UDim2.new(0,140,0,16),
        C(235,235,245), Enum.TextXAlignment.Right, 10)
    Cut.frameLbl.Font = Enum.Font.Code
    Cut.statusLbl = F.makeLabel(vp, "type an animation ID to start", UDim2.new(0,10,1,-24),
        UDim2.new(1,-20,0,16), C(150,150,170), Enum.TextXAlignment.Left, 9)

    -- which note the preview is showing, big in the corner
    Cut.noteLbl = F.makeLabel(vp, "", UDim2.new(0,10,0,26), UDim2.new(0,220,0,20),
        C(255,255,255), Enum.TextXAlignment.Left, 13)
    Cut.noteLbl.Font = Enum.Font.GothamBlack

    F.makeLabel(pg, "ROTATE", UDim2.new(0,8,0,326), UDim2.new(0,60,0,16),
        C(160,160,160), Enum.TextXAlignment.Left, 9)
    F.makeSlider(pg, UDim2.new(0,72,0,329), UDim2.new(1,-160,0,10), -180, 180, 0, function(v)
        Cut.yaw = v
        if Cut.clone then
            pcall(function() Cut.clone:PivotTo(CFrame.new(0,3,0) * CFrame.Angles(0, math.rad(v), 0)) end)
        end
    end)
    local rebuild = F.makeBtn(pg, "RIG", UDim2.new(1,-80,0,322), UDim2.new(0,72,0,22), C(45,40,60), nil, 9)
    rebuild.MouseButton1Click:Connect(function()
        Cut.buildClone()
        Cut.editDir(Cut.selDir, true)
    end)

    -- ── timeline ──
    local tlY = 356
    Cut.timeLbl = F.makeLabel(pg, "0.00s  /  0.00s", UDim2.new(0,8,0,tlY), UDim2.new(0,200,0,18),
        C(235,235,245), Enum.TextXAlignment.Left, 12)
    Cut.timeLbl.Font = Enum.Font.Code

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1,-16,0,64); bar.Position = UDim2.new(0,8,0,tlY+22)
    bar.BackgroundColor3 = C(12,11,18); bar.BorderSizePixel = 0
    bar.Active = true
    bar.Parent = pg
    F.uiCorner(bar, UDim.new(0,6))
    F.uiStroke(bar, C(255,255,255), 1).Transparency = 0.8
    Cut.bar = bar

    Cut.sliceFrames = {}
    for i, dir in ipairs(ARROW_ORDER) do
        if i > 1 then
            local sep = Instance.new("Frame")
            sep.Size = UDim2.new(1,0,0,1); sep.Position = UDim2.new(0,0,(i-1)/4,0)
            sep.BackgroundColor3 = C(255,255,255); sep.BackgroundTransparency = 0.9
            sep.BorderSizePixel = 0; sep.Parent = bar
        end
        local f = Instance.new("Frame")
        f.BackgroundColor3 = ARROW_COLORS[dir].hit
        f.BorderSizePixel = 0; f.Visible = false; f.Parent = bar
        F.uiCorner(f, UDim.new(0,3))
        Cut.sliceFrames[dir] = f
    end
    for q = 1, 3 do
        local tk = Instance.new("Frame")
        tk.Size = UDim2.new(0,1,1,0); tk.Position = UDim2.new(q/4,0,0,0)
        tk.BackgroundColor3 = C(255,255,255); tk.BackgroundTransparency = 0.85
        tk.BorderSizePixel = 0; tk.Parent = bar
    end

    local head = Instance.new("Frame")
    head.Size = UDim2.new(0,2,1,8); head.Position = UDim2.new(0,-1,0,-4)
    head.BackgroundColor3 = C(255,255,255); head.BorderSizePixel = 0
    head.ZIndex = 5; head.Parent = bar
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0,12,0,12); knob.AnchorPoint = Vector2.new(0.5,1)
    knob.Position = UDim2.new(0.5,0,0,0); knob.BackgroundColor3 = C(255,255,255)
    knob.BorderSizePixel = 0; knob.ZIndex = 5; knob.Parent = head
    F.uiCorner(knob, UDim.new(1,0))
    Cut.head = head

    local scrubbing = false
    local function scrubTo(x)
        if Cut.length <= 0 then return end
        local w = bar.AbsoluteSize.X
        if w <= 0 then return end
        local a = math.clamp((x - bar.AbsolutePosition.X) / w, 0, 1)
        Cut.setPlaying(false)
        Cut.seek(a * Cut.length)
    end
    bar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            scrubbing = true
            scrubTo(inp.Position.X)
        end
    end)
    F.own(UserInputService.InputChanged:Connect(function(inp)
        if scrubbing and (inp.UserInputType == Enum.UserInputType.MouseMovement
            or inp.UserInputType == Enum.UserInputType.Touch) then
            scrubTo(inp.Position.X)
        end
    end))
    F.own(UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            scrubbing = false
        end
    end))

    -- ── transport ──
    local trY = tlY + 94
    local function tbtn(txt, x, w, col, fn)
        local b = F.makeBtn(pg, txt, UDim2.new(0,x,0,trY), UDim2.new(0,w,0,28), col, nil, 10)
        b.MouseButton1Click:Connect(fn)
        return b
    end
    tbtn("|<", 8, 44, C(45,40,60), function() Cut.setPlaying(false); Cut.seek(0) end)
    tbtn("<", 56, 44, C(45,40,60), function() Cut.setPlaying(false); Cut.seek(Cut.playhead - 1 / Cut.fps) end)
    Cut.playBtn = tbtn("PLAY", 104, 96, C(60,190,120), function() Cut.setPlaying(not Cut.playing) end)
    tbtn(">", 204, 44, C(45,40,60), function() Cut.setPlaying(false); Cut.seek(Cut.playhead + 1 / Cut.fps) end)
    tbtn(">|", 252, 44, C(45,40,60), function() Cut.setPlaying(false); Cut.seek(Cut.length) end)
    local loopBtn
    loopBtn = tbtn("LOOP: ALL", 300, 96, C(45,40,60), function()
        Cut.loopSlice = not Cut.loopSlice
        loopBtn.Text = Cut.loopSlice and "LOOP: SLICE" or "LOOP: ALL"
        loopBtn.BackgroundColor3 = Cut.loopSlice and C(70,120,255) or C(45,40,60)
    end)

    -- ── notes ──
    local seY = trY + 40
    F.makeDivider(pg, seY, THEMES[currentThemeName].accent)
    local seTitle = F.makeLabel(pg, "NOTES", UDim2.new(0,8,0,seY+6), UDim2.new(0,120,0,18),
        C(255,80,180), Enum.TextXAlignment.Left, 11)
    seTitle.Font = Enum.Font.GothamBold
    F.regText(seTitle)
    F.makeLabel(pg, "Type an ID into a note to load it. Click a note to see its animation.",
        UDim2.new(0,8,0,seY+24), UDim2.new(1,-16,0,14), C(130,130,150), Enum.TextXAlignment.Left, 9)

    Cut.dirBtns = {}
    local rowFrames = {}
    local function selectDir(dir)
        for d, b in pairs(Cut.dirBtns) do
            b.BackgroundColor3 = (d == dir) and ARROW_COLORS[d].hit or C(35,35,55)
            b.TextColor3 = (d == dir) and C(15,15,20) or C(238,238,248)
        end
        for d, rf in pairs(rowFrames) do
            rf.BackgroundTransparency = (d == dir) and 0.1 or 0.6
        end
        if Cut.noteLbl then
            Cut.noteLbl.Text = ARROW_SYMBOLS[dir] .. " " .. dir
            Cut.noteLbl.TextColor3 = ARROW_COLORS[dir].hit
        end
        Cut.editDir(dir)
        Cut.drawSlices()
    end
    Cut.selectDir = selectDir

    for i, dir in ipairs(ARROW_ORDER) do
        local b = F.makeBtn(pg, ARROW_SYMBOLS[dir] .. " " .. dir,
            UDim2.new(0, 8 + (i-1) * 100, 0, seY + 44), UDim2.new(0, 96, 0, 30), C(35,35,55), nil, 10)
        Cut.dirBtns[dir] = b
        b.MouseButton1Click:Connect(function() selectDir(dir) end)
    end

    local mY = seY + 82
    local markStart = F.makeBtn(pg, "MARK START", UDim2.new(0,8,0,mY), UDim2.new(0,126,0,28), C(60,190,120), nil, 10)
    local markStop  = F.makeBtn(pg, "MARK STOP",  UDim2.new(0,140,0,mY), UDim2.new(0,126,0,28), C(200,70,70), nil, 10)
    local playSlice = F.makeBtn(pg, "PLAY SLICE", UDim2.new(0,272,0,mY), UDim2.new(0,124,0,28), C(70,120,255), nil, 10)
    markStart.MouseButton1Click:Connect(function()
        if Cut.length <= 0 then F.notify("Load an animation first", "warn"); return end
        cutterSlices[Cut.selDir].start = Cut.playhead
        Cut.drawSlices()
    end)
    markStop.MouseButton1Click:Connect(function()
        if Cut.length <= 0 then F.notify("Load an animation first", "warn"); return end
        cutterSlices[Cut.selDir].stop = Cut.playhead
        Cut.drawSlices()
    end)
    playSlice.MouseButton1Click:Connect(function()
        if Cut.length <= 0 then return end
        Cut.loopSlice = true
        loopBtn.Text = "LOOP: SLICE"; loopBtn.BackgroundColor3 = C(70,120,255)
        local s = cutterSlices[Cut.selDir]
        Cut.seek(math.min(s.start, s.stop))
        Cut.setPlaying(true)
    end)

    -- one card per note: its own animation ID, then its in/out times
    local nY = mY + 38
    local CARD = 66
    Cut.startBoxes, Cut.stopBoxes, Cut.idBoxes = {}, {}, {}
    for i, dir in ipairs(ARROW_ORDER) do
        local ry = nY + (i-1) * CARD
        local d = dir

        local card = Instance.new("Frame")
        card.Size = UDim2.new(1,-16,0,CARD - 6); card.Position = UDim2.new(0,8,0,ry)
        card.BackgroundColor3 = C(24,22,33); card.BackgroundTransparency = 0.6
        card.BorderSizePixel = 0; card.Parent = pg
        F.uiCorner(card, UDim.new(0,7))
        local cs = F.uiStroke(card, ARROW_COLORS[dir].hit, 1)
        cs.Transparency = 0.6
        rowFrames[dir] = card

        local lbl = F.makeLabel(card, ARROW_SYMBOLS[dir] .. " " .. dir, UDim2.new(0,8,0,4),
            UDim2.new(0,70,0,24), ARROW_COLORS[dir].hit, Enum.TextXAlignment.Left, 11)
        lbl.Font = Enum.Font.GothamBold

        -- this note's own animation
        local idBox = F.makeBox(card, UDim2.new(0,80,0,4), UDim2.new(1,-168,0,24),
            "uses default animation", cutterSlices[dir].id or "")
        idBox.TextSize = 10
        Cut.idBoxes[dir] = idBox
        local function commitId()
            local clean = (idBox.Text:gsub("%D",""))
            local changed = clean ~= (cutterSlices[d].id or "")
            cutterSlices[d].id = clean
            idBox.Text = clean
            if clean ~= "" then F.cutterTrackFor(clean) end
            -- typing an ID loads it straight into the preview
            if changed then
                Cut.noteLbl.Text = ARROW_SYMBOLS[d] .. " " .. d
                selectDir(d)
                Cut.editDir(d, true)
            end
        end
        idBox.FocusLost:Connect(function() commitId() end)

        local view = F.makeBtn(card, "VIEW", UDim2.new(1,-82,0,4), UDim2.new(0,74,0,24),
            C(70,120,255), nil, 9)
        view.MouseButton1Click:Connect(function() commitId(); selectDir(d) end)

        -- in / out
        F.makeLabel(card, "IN", UDim2.new(0,8,0,32), UDim2.new(0,20,0,24), C(140,140,160), Enum.TextXAlignment.Left, 9)
        local sb = F.makeBox(card, UDim2.new(0,28,0,32), UDim2.new(0,70,0,24), "0.00",
            string.format("%.2f", cutterSlices[dir].start))
        F.makeLabel(card, "OUT", UDim2.new(0,104,0,32), UDim2.new(0,28,0,24), C(140,140,160), Enum.TextXAlignment.Left, 9)
        local eb = F.makeBox(card, UDim2.new(0,134,0,32), UDim2.new(0,70,0,24), "0.00",
            string.format("%.2f", cutterSlices[dir].stop))
        Cut.startBoxes[dir], Cut.stopBoxes[dir] = sb, eb
        sb.FocusLost:Connect(function()
            local n = tonumber(sb.Text)
            if n then cutterSlices[d].start = math.max(0, n) end
            Cut.drawSlices()
        end)
        eb.FocusLost:Connect(function()
            local n = tonumber(eb.Text)
            if n then cutterSlices[d].stop = math.max(0, n) end
            Cut.drawSlices()
        end)

        local goIn = F.makeBtn(card, "GO IN", UDim2.new(0,212,0,32), UDim2.new(0,64,0,24), C(45,40,60), nil, 9)
        local goOut = F.makeBtn(card, "GO OUT", UDim2.new(0,280,0,32), UDim2.new(0,64,0,24), C(45,40,60), nil, 9)
        goIn.MouseButton1Click:Connect(function()
            selectDir(d); Cut.setPlaying(false); Cut.seek(cutterSlices[d].start)
        end)
        goOut.MouseButton1Click:Connect(function()
            selectDir(d); Cut.setPlaying(false); Cut.seek(cutterSlices[d].stop)
        end)
    end

    -- placeholder text shows what a blank note will actually use
    Cut.refreshIdBoxes = function()
        for _, dir in ipairs(ARROW_ORDER) do
            local b = Cut.idBoxes[dir]
            if b then
                b.PlaceholderText = (cutterAnimId ~= "")
                    and ("default: " .. cutterAnimId) or "type an animation ID"
            end
        end
    end
    Cut.refreshIdBoxes()

    -- ── quick split ──
    local qY = nY + 4 * CARD + 4
    local split = F.makeBtn(pg, "SPLIT THIS ANIM INTO 4", UDim2.new(0,8,0,qY), UDim2.new(0,250,0,30), C(70,120,255), nil, 10)
    split.MouseButton1Click:Connect(function()
        if Cut.length <= 0 then F.notify("Load an animation first", "warn"); return end
        -- splits the animation on screen across every note that uses it
        local users = {}
        for _, dir in ipairs(ARROW_ORDER) do
            if F.cutterSliceId(dir) == Cut.editId then table.insert(users, dir) end
        end
        if #users == 0 then return end
        local q = Cut.length / #users
        for n, dir in ipairs(users) do
            cutterSlices[dir].start = (n - 1) * q
            cutterSlices[dir].stop = n * q
        end
        Cut.drawSlices()
        F.notify("Split across " .. #users .. " note" .. (#users == 1 and "" or "s"), "success")
    end)
    local clear = F.makeBtn(pg, "RESET TIMES", UDim2.new(0,266,0,qY), UDim2.new(0,130,0,30), C(170,35,35), nil, 10)
    clear.MouseButton1Click:Connect(function()
        for _, dir in ipairs(ARROW_ORDER) do cutterSlices[dir].start, cutterSlices[dir].stop = 0, 0 end
        Cut.drawSlices()
    end)

    F.makeLabel(pg, "Your note keys play these slices while the cutter is ON.",
        UDim2.new(0,8,0,qY+38), UDim2.new(1,-16,0,16), C(120,120,140), Enum.TextXAlignment.Left, 9)

    -- ── response ──
    local rY = qY + 62
    F.makeDivider(pg, rY, THEMES[currentThemeName].accent)
    local rTitle = F.makeLabel(pg, "RESPONSE", UDim2.new(0,8,0,rY+6), UDim2.new(0,120,0,18),
        C(255,80,180), Enum.TextXAlignment.Left, 11)
    rTitle.Font = Enum.Font.GothamBold
    F.regText(rTitle)
    F.makeLabel(pg, "How fast a slice lands when you press. Lower is snappier for fast playing.",
        UDim2.new(0,8,0,rY+24), UDim2.new(1,-16,0,14), C(130,130,150), Enum.TextXAlignment.Left, 9)

    local snapBtn = F.makeBtn(pg, Cut.snap and "SNAP: ON" or "SNAP: OFF",
        UDim2.new(0,8,0,rY+44), UDim2.new(0,126,0,26),
        Cut.snap and C(255,160,40) or C(35,35,55), nil, 9)
    snapBtn.MouseButton1Click:Connect(function()
        Cut.snap = not Cut.snap
        snapBtn.Text = Cut.snap and "SNAP: ON" or "SNAP: OFF"
        snapBtn.BackgroundColor3 = Cut.snap and C(255,160,40) or C(35,35,55)
    end)
    F.makeLabel(pg, "Skip the motion and land on the pose instantly.",
        UDim2.new(0,142,0,rY+44), UDim2.new(1,-150,0,26), C(120,120,140), Enum.TextXAlignment.Left, 9)

    F.makeLabel(pg, "REACH TIME", UDim2.new(0,8,0,rY+78), UDim2.new(0,200,0,18),
        C(160,160,160), Enum.TextXAlignment.Left, 10)
    local reachLbl = F.makeLabel(pg, string.format("%.2fs", Cut.reach),
        UDim2.new(0,306,0,rY+78), UDim2.new(0,90,0,18), C(255,80,180), Enum.TextXAlignment.Right, 10)
    F.regText(reachLbl)
    F.makeSlider(pg, UDim2.new(0,8,0,rY+98), UDim2.new(1,-16,0,12), 0.02, 0.6, Cut.reach, function(v)
        Cut.reach = v
        reachLbl.Text = string.format("%.2fs", v)
    end)

    -- ── reverse ──
    local rvY = rY + 124
    F.makeLabel(pg, "PLAY IT BACK", UDim2.new(0,8,0,rvY), UDim2.new(0,200,0,18),
        C(160,160,160), Enum.TextXAlignment.Left, 10)
    local rvHelp = {
        OFF     = "Stays on the pose (Pose Hold still applies).",
        AUTO    = "Lands, pauses, then goes back to its start on its own.",
        RELEASE = "Holds while you hold the key, goes back when you let go.",
    }
    local rvBtn = F.makeBtn(pg, "", UDim2.new(0,8,0,rvY+20), UDim2.new(0,160,0,26), C(35,35,55), nil, 10)
    local rvNote = F.makeLabel(pg, "", UDim2.new(0,176,0,rvY+20), UDim2.new(1,-184,0,26),
        C(120,120,140), Enum.TextXAlignment.Left, 9)
    rvNote.TextWrapped = true
    local function syncRv()
        rvBtn.Text = "REVERSE: " .. (Cut.reverse == "RELEASE" and "ON RELEASE" or Cut.reverse)
        rvBtn.BackgroundColor3 = (Cut.reverse == "OFF") and C(35,35,55) or C(255,160,40)
        rvNote.Text = rvHelp[Cut.reverse] or ""
    end
    rvBtn.MouseButton1Click:Connect(function()
        local order = { "OFF", "AUTO", "RELEASE" }
        Cut.reverse = order[((table.find(order, Cut.reverse) or 1) % #order) + 1]
        syncRv()
    end)
    syncRv()

    local rvRows = {
        { key = "returnPause", label = "PAUSE ON THE POSE (AUTO)", min = 0,    max = 1.5, fmt = "%.2fs" },
        { key = "returnTime",  label = "TIME TO GO BACK",          min = 0.03, max = 1.5, fmt = "%.2fs" },
    }
    for i, s in ipairs(rvRows) do
        local ry = rvY + 54 + (i-1) * 42
        F.makeLabel(pg, s.label, UDim2.new(0,8,0,ry), UDim2.new(0,240,0,18), C(160,160,160), Enum.TextXAlignment.Left, 10)
        local v = F.makeLabel(pg, string.format(s.fmt, Cut[s.key]), UDim2.new(0,306,0,ry), UDim2.new(0,90,0,18),
            C(255,80,180), Enum.TextXAlignment.Right, 10)
        F.regText(v)
        local ck, cf = s.key, s.fmt
        F.makeSlider(pg, UDim2.new(0,8,0,ry+20), UDim2.new(1,-16,0,12), s.min, s.max, Cut[s.key], function(val)
            Cut[ck] = val
            v.Text = string.format(cf, val)
        end)
    end

    local haY = rvY + 54 + #rvRows * 42
    local haBtn = F.makeBtn(pg, "", UDim2.new(0,8,0,haY), UDim2.new(0,190,0,26), C(35,35,55), nil, 9)
    local haNote = F.makeLabel(pg, "", UDim2.new(0,206,0,haY), UDim2.new(1,-214,0,26),
        C(120,120,140), Enum.TextXAlignment.Left, 9)
    haNote.TextWrapped = true
    local function syncHa()
        haBtn.Text = Cut.holdAfterReturn and "AFTER GOING BACK: HOLD" or "AFTER GOING BACK: IDLE"
        haBtn.BackgroundColor3 = Cut.holdAfterReturn and C(255,160,40) or C(35,35,55)
        haNote.Text = Cut.holdAfterReturn and "Stays on the start frame. Pose Hold sets how long."
            or "Blends out to idle once it's back."
    end
    haBtn.MouseButton1Click:Connect(function()
        Cut.holdAfterReturn = not Cut.holdAfterReturn
        syncHa()
    end)
    syncHa()

    Cut.buildSlots(pg, haY + 40, defBox)

    Cut.startLoop()
    task.defer(function()
        Cut.buildClone()
        selectDir(Cut.selDir or "LEFT")
    end)
end

-- ============================================================
--  CUTTER SLOTS — save a whole cutter setup, load it back later
--  A slot holds the default animation and, for every note, its own
--  animation and its in/out times. Slots live in library.json.
-- ============================================================
function Cut.snapshot(name)
    local s = { name = name, id = cutterAnimId, slices = {} }
    for _, k in ipairs(ARROW_ORDER) do
        local c = cutterSlices[k] or {}
        s.slices[k] = { start = c.start or 0, stop = c.stop or 0, id = c.id or "" }
    end
    return s
end

function Cut.slotSummary(s)
    local own = 0
    for _, k in ipairs(ARROW_ORDER) do
        if (s.slices[k].id or "") ~= "" then own = own + 1 end
    end
    if own > 0 then return own .. (own == 1 and " own anim" or " own anims") end
    return (s.id ~= "") and ("anim " .. s.id:sub(1, 6) .. "…") or "no anim"
end

function Cut.applySlot(s, defBox)
    cutterAnimId = s.id
    for _, k in ipairs(ARROW_ORDER) do
        local v = s.slices[k]
        cutterSlices[k] = { start = v.start, stop = v.stop, id = v.id }
        if Cut.idBoxes[k] then Cut.idBoxes[k].Text = v.id end
    end
    if defBox then defBox.Text = cutterAnimId end
    if Cut.refreshIdBoxes then Cut.refreshIdBoxes() end
    pcall(F.cutterLoadTrack)
    pcall(function() Cut.editDir(Cut.selDir or "LEFT", true) end)
    Cut.drawSlices()
    F.notify("Loaded cutter slot: " .. (s.name ~= "" and s.name or "?"), "success")
end

function Cut.buildSlots(pg, y, defBox)
    local C = Color3.fromRGB
    F.makeDivider(pg, y, THEMES[currentThemeName].accent)
    local t = F.makeLabel(pg, "CUTTER SLOTS", UDim2.new(0,8,0,y+6), UDim2.new(0,200,0,18),
        C(255,80,180), Enum.TextXAlignment.Left, 11)
    t.Font = Enum.Font.GothamBold
    F.regText(t)
    local help = F.makeLabel(pg, "SAVE keeps the whole setup above: the default animation, every note's own animation and its in/out. LOAD puts it back. Slots are the same whichever save slot you're on.",
        UDim2.new(0,8,0,y+24), UDim2.new(1,-16,0,28), C(130,130,150), Enum.TextXAlignment.Left, 9)
    help.TextWrapped = true

    local ry = y + 58
    for i = 1, Lib.CUT_SLOTS do
        local slot = i
        local nameBox = F.makeBox(pg, UDim2.new(0,8,0,ry), UDim2.new(0,146,0,26), "slot " .. i,
            Lib.cutter[i] and Lib.cutter[i].name or "")
        nameBox.TextSize = 10
        local info = F.makeLabel(pg, "", UDim2.new(0,158,0,ry), UDim2.new(0,80,0,26),
            C(130,130,150), Enum.TextXAlignment.Left, 9)
        info.TextTruncate = Enum.TextTruncate.AtEnd
        local saveB = F.makeBtn(pg, "SAVE", UDim2.new(0,240,0,ry), UDim2.new(0,52,0,26), C(60,190,120), nil, 9)
        local loadB = F.makeBtn(pg, "LOAD", UDim2.new(0,296,0,ry), UDim2.new(0,56,0,26), C(35,35,55), nil, 9)
        local delB = F.makeBtn(pg, "✕", UDim2.new(0,356,0,ry), UDim2.new(0,40,0,26), C(120,40,40), nil, 10)

        local function paint()
            local s = Lib.cutter[slot]
            info.Text = s and Cut.slotSummary(s) or "empty"
            loadB.BackgroundColor3 = s and C(70,120,255) or C(35,35,55)
        end
        saveB.MouseButton1Click:Connect(function()
            local nm = nameBox.Text:gsub("[%c]", ""):sub(1, 40)
            nm = nm:match("^%s*(.-)%s*$")
            if nm == "" then nm = "slot " .. slot end
            nameBox.Text = nm
            Lib.cutter[slot] = Cut.snapshot(nm)
            Lib.save()
            paint()
            F.notify("Cutter saved to slot " .. slot .. ": " .. nm, "success")
        end)
        loadB.MouseButton1Click:Connect(function()
            local s = Lib.cutter[slot]
            if not s then F.notify("Slot " .. slot .. " is empty", "warn"); return end
            nameBox.Text = s.name
            Cut.applySlot(s, defBox)
        end)
        delB.MouseButton1Click:Connect(function()
            if not Lib.cutter[slot] then return end
            Lib.cutter[slot] = nil
            nameBox.Text = ""
            Lib.save()
            paint()
            F.notify("Slot " .. slot .. " cleared", "info")
        end)
        paint()
        ry = ry + 32
    end
    return ry
end

function F.buildTab_Cam(pages)
    local pgCam = pages["🎥 CAM"]

    local camTitle = F.makeLabel(pgCam, "🎥 FNF CINEMATIC CAMERA", UDim2.new(0,8,0,6),
        UDim2.new(1,-16,0,20), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Left, 12)
    F.regText(camTitle)
    F.makeLabel(pgCam, "Triangle view between you & opponent. Pans to whoever is singing. Shake + letterbox on aggressive exchanges.",
        UDim2.new(0,8,0,26), UDim2.new(1,-16,0,28), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 9)
    F.makeDivider(pgCam, 58, Color3.fromRGB(0,200,255))

    local camBtn = F.makeBtn(pgCam, "📴  CAMERA OFF", UDim2.new(0,8,0,66), UDim2.new(1,-16,0,32), Color3.fromRGB(35,35,55), nil, 11)
    camBtn.MouseButton1Click:Connect(function()
        local newState = not FNFCamera.enabled
        FNFCamera:SetEnabled(newState)
        camBtn.Text = newState and "🎥  CAMERA ON" or "📴  CAMERA OFF"
        camBtn.BackgroundColor3 = newState and THEMES[currentThemeName].accent or Color3.fromRGB(35,35,55)
        F.notify(newState and "Cinematic camera enabled" or "Cinematic camera disabled", "info")
    end)

    local camStatusLbl = F.makeLabel(pgCam, "Focus: CENTER | Intensity: 0%", UDim2.new(0,8,0,106),
        UDim2.new(1,-16,0,18), Color3.fromRGB(160,160,180), Enum.TextXAlignment.Left, 10)
    FNFCamera.statusCb = function(focus, intensity01)
        camStatusLbl.Text = string.format("Focus: %s | Intensity: %d%%", focus, math.floor(intensity01*100))
    end

    F.makeLabel(pgCam, "SENSITIVITY (how fast intensity builds)", UDim2.new(0,8,0,132), UDim2.new(1,-16,0,20), Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    F.makeSlider(pgCam, UDim2.new(0,8,0,154), UDim2.new(1,-16,0,14), 0.5, 2.5, 1, function(v) FNFCamera:SetSensitivity(v) end)

    F.makeLabel(pgCam, "MAX SHAKE", UDim2.new(0,8,0,178), UDim2.new(0,140,0,20), Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    F.makeSlider(pgCam, UDim2.new(0,8,0,200), UDim2.new(1,-16,0,14), 0, 1, 1, function(v) FNFCamera:SetShakeScale(v) end)

    F.makeLabel(pgCam, "MAX ZOOM", UDim2.new(0,8,0,224), UDim2.new(0,140,0,20), Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    F.makeSlider(pgCam, UDim2.new(0,8,0,246), UDim2.new(1,-16,0,14), 0, 1, 1, function(v) FNFCamera:SetZoomScale(v) end)

    -- ── CAMERA POSITION CONTROLS ──
    F.makeDivider(pgCam, 274, Color3.fromRGB(0,200,255))
    local posTitle = F.makeLabel(pgCam, "📐 CAMERA POSITION", UDim2.new(0,8,0,280),
        UDim2.new(1,-16,0,18), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Left, 11)
    F.regText(posTitle)

    local flipBtn = F.makeBtn(pgCam, "↔  LEFT SIDE", UDim2.new(0,8,0,304), UDim2.new(1,-16,0,30), Color3.fromRGB(70,120,255), nil, 11)
    flipBtn.MouseButton1Click:Connect(function()
        FNFCamera.camFlipped = not FNFCamera.camFlipped
        flipBtn.Text = FNFCamera.camFlipped and "↔  RIGHT SIDE" or "↔  LEFT SIDE"
        F.notify(FNFCamera.camFlipped and "Camera flipped to right side" or "Camera flipped to left side", "info")
    end)

    F.makeLabel(pgCam, "DISTANCE", UDim2.new(0,8,0,342), UDim2.new(0,100,0,20), Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local distLbl = F.makeLabel(pgCam, string.format("%.0f", FNFCamera.camDistance),
        UDim2.new(0,340,0,342), UDim2.new(0,70,0,20), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Right, 10)
    F.regText(distLbl)
    F.makeSlider(pgCam, UDim2.new(0,8,0,364), UDim2.new(1,-16,0,14), 5, 30, FNFCamera.camDistance, function(v)
        FNFCamera.camDistance = v
        distLbl.Text = string.format("%.0f", v)
    end)

    F.makeLabel(pgCam, "HEIGHT", UDim2.new(0,8,0,388), UDim2.new(0,100,0,20), Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local heightLbl = F.makeLabel(pgCam, string.format("%.1f", FNFCamera.camHeight),
        UDim2.new(0,340,0,388), UDim2.new(0,70,0,20), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Right, 10)
    F.regText(heightLbl)
    F.makeSlider(pgCam, UDim2.new(0,8,0,410), UDim2.new(1,-16,0,14), 0, 15, FNFCamera.camHeight, function(v)
        FNFCamera.camHeight = v
        heightLbl.Text = string.format("%.1f", v)
    end)

    F.makeLabel(pgCam, "HORIZONTAL", UDim2.new(0,8,0,434), UDim2.new(0,110,0,20), Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local horzLbl = F.makeLabel(pgCam, string.format("%.1f", FNFCamera.camHorizontal),
        UDim2.new(0,340,0,434), UDim2.new(0,70,0,20), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Right, 10)
    F.regText(horzLbl)
    F.makeSlider(pgCam, UDim2.new(0,8,0,456), UDim2.new(1,-16,0,14), -10, 10, FNFCamera.camHorizontal, function(v)
        FNFCamera.camHorizontal = v
        horzLbl.Text = string.format("%.1f", v)
    end)

    F.makeLabel(pgCam, "ORBIT ANGLE", UDim2.new(0,8,0,480), UDim2.new(0,110,0,20), Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local angleLbl = F.makeLabel(pgCam, string.format("%.0f°", FNFCamera.camAngle),
        UDim2.new(0,340,0,480), UDim2.new(0,70,0,20), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Right, 10)
    F.regText(angleLbl)
    F.makeSlider(pgCam, UDim2.new(0,8,0,502), UDim2.new(1,-16,0,14), -90, 90, FNFCamera.camAngle, function(v)
        FNFCamera.camAngle = v
        angleLbl.Text = string.format("%.0f°", v)
    end)

    F.makeLabel(pgCam, "BASE FOV", UDim2.new(0,8,0,526), UDim2.new(0,100,0,20), Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local fovLbl = F.makeLabel(pgCam, string.format("%.0f", CAM_CFG.BaseFOV),
        UDim2.new(0,340,0,526), UDim2.new(0,70,0,20), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Right, 10)
    F.regText(fovLbl)
    F.makeSlider(pgCam, UDim2.new(0,8,0,548), UDim2.new(1,-16,0,14), 40, 110, CAM_CFG.BaseFOV, function(v)
        CAM_CFG.BaseFOV = v
        fovLbl.Text = string.format("%.0f", v)
    end)

    local resetCamBtn = F.makeBtn(pgCam, "↺  RESET POSITION", UDim2.new(0,8,0,572), UDim2.new(1,-16,0,28), Color3.fromRGB(170,35,35), nil, 10)
    resetCamBtn.MouseButton1Click:Connect(function()
        FNFCamera.camDistance = 14; FNFCamera.camHeight = 5
        FNFCamera.camHorizontal = 0; FNFCamera.camAngle = 0
        FNFCamera.camFlipped = false; CAM_CFG.BaseFOV = 70
        distLbl.Text = "14"; heightLbl.Text = "5.0"
        horzLbl.Text = "0.0"; angleLbl.Text = "0°"; fovLbl.Text = "70"
        flipBtn.Text = "↔  LEFT SIDE"
        F.notify("Camera position reset", "info")
    end)

    -- ── OPPONENT SEARCH ──
    F.makeDivider(pgCam, 612, Color3.fromRGB(255,80,180))
    local oppTitle = F.makeLabel(pgCam, "🎤 SET OPPONENT", UDim2.new(0,8,0,618),
        UDim2.new(1,-16,0,18), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Left, 11)
    F.regText(oppTitle)
    F.makeLabel(pgCam, "Pick any player — camera will triangle between you and them.",
        UDim2.new(0,8,0,636), UDim2.new(1,-16,0,16), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 9)

    local camOppLbl = F.makeLabel(pgCam, "Opponent: none", UDim2.new(0,8,0,654),
        UDim2.new(1,-16,0,16), Color3.fromRGB(0,200,255), Enum.TextXAlignment.Left, 10)

    local oppSearchBox = F.makeBox(pgCam, UDim2.new(0,8,0,674), UDim2.new(1,-16,0,28), "Type player name...")
    local oppResultsList = Instance.new("ScrollingFrame")
    oppResultsList.Size = UDim2.new(1,-16,0,90); oppResultsList.Position = UDim2.new(0,8,0,706)
    oppResultsList.BackgroundColor3 = Color3.fromRGB(18,18,26); oppResultsList.BorderSizePixel = 0
    oppResultsList.ScrollBarThickness = 3; oppResultsList.CanvasSize = UDim2.new(0,0,0,0)
    oppResultsList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    oppResultsList.Parent = pgCam; F.uiCorner(oppResultsList, UDim.new(0,6))
    local oppResultsLayout = Instance.new("UIListLayout")
    oppResultsLayout.Padding = UDim.new(0,2); oppResultsLayout.Parent = oppResultsList

    local function camPickPlayer(plr)
        if not plr or not plr.Character then F.notify("Player has no character yet", "warn"); return end
        F.pickOpponent(plr)
        camOppLbl.Text = "Opponent: " .. plr.Name
        oppSearchBox.Text = ""
        for _, c in ipairs(oppResultsList:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        F.notify("Opponent set: " .. plr.Name .. " — camera will track both of you", "success")
    end

    local function refreshOppResults(query)
        for _, c in ipairs(oppResultsList:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        if query == "" then return end
        query = query:lower()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Name:lower():find(query, 1, true) then
                local row = F.makeBtn(oppResultsList, plr.Name, UDim2.new(0,2,0,0), UDim2.new(1,-4,0,24), Color3.fromRGB(28,28,42))
                row.MouseButton1Click:Connect(function() camPickPlayer(plr) end)
            end
        end
    end
    oppSearchBox:GetPropertyChangedSignal("Text"):Connect(function() refreshOppResults(oppSearchBox.Text) end)

    local clearOppBtn = F.makeBtn(pgCam, "✕ CLEAR OPPONENT", UDim2.new(0,8,0,802), UDim2.new(1,-16,0,26), Color3.fromRGB(170,35,35), nil, 10)
    clearOppBtn.MouseButton1Click:Connect(function()
        currentTarget = nil
        F.stopWatchingTargetAnims()
        if spacing then spacing:SetOpponent(nil) end
        FNFCamera:SetOpponentCharacter(nil)
        camOppLbl.Text = "Opponent: none"
        F.notify("Opponent cleared — camera centers on you", "info")
    end)

    -- ── MATCH SEARCH ──
    F.makeDivider(pgCam, 838, Color3.fromRGB(0,200,255))
    local matchTitle = F.makeLabel(pgCam, "🔍 FIND A MATCH (SAME SCRIPT)", UDim2.new(0,8,0,844),
        UDim2.new(1,-16,0,18), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Left, 11)
    F.regText(matchTitle)
    F.makeLabel(pgCam, "Only finds other players currently running this injector.",
        UDim2.new(0,8,0,862), UDim2.new(1,-16,0,16), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 9)

    local matchSearchBox = F.makeBox(pgCam, UDim2.new(0,8,0,882), UDim2.new(1,-96,0,28), "Search name (blank = everyone)")
    local matchSearchBtn = F.makeBtn(pgCam, "🔍 SCAN", UDim2.new(1,-84,0,882), UDim2.new(0,76,0,28), Color3.fromRGB(70,120,255), nil, 10)

    local matchResults = Instance.new("ScrollingFrame")
    matchResults.Size = UDim2.new(1,-16,0,120); matchResults.Position = UDim2.new(0,8,0,916)
    matchResults.BackgroundColor3 = Color3.fromRGB(18,18,26); matchResults.BorderSizePixel = 0
    matchResults.ScrollBarThickness = 3; matchResults.CanvasSize = UDim2.new(0,0,0,0)
    matchResults.AutomaticCanvasSize = Enum.AutomaticSize.Y
    matchResults.Parent = pgCam; F.uiCorner(matchResults, UDim.new(0,6))
    local matchResultsLayout = Instance.new("UIListLayout")
    matchResultsLayout.Padding = UDim.new(0,2); matchResultsLayout.Parent = matchResults

    local function renderMatchResults(list)
        for _, c in ipairs(matchResults:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        if #list == 0 then
            F.notify("No other players with the injector found", "info")
            return
        end
        for _, entry in ipairs(list) do
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1,-4,0,26); row.BackgroundColor3 = Color3.fromRGB(24,24,36)
            row.BorderSizePixel = 0; row.Parent = matchResults
            F.uiCorner(row, UDim.new(0,4))
            F.makeLabel(row, entry.Name, UDim2.new(0,6,0,0), UDim2.new(1,-70,1,0),
                Color3.fromRGB(200,200,215), Enum.TextXAlignment.Left, 10)
            local matchBtn = F.makeBtn(row, "🎯 MATCH", UDim2.new(1,-64,0,2), UDim2.new(0,60,0,22), Color3.fromRGB(60,190,120), nil, 9)
            matchBtn.MouseButton1Click:Connect(function()
                local plr = Players:FindFirstChild(entry.Name)
                if plr then
                    camPickPlayer(plr)
                else
                    F.notify("Player left before matching", "warn")
                end
            end)
        end
    end

    matchSearchBtn.MouseButton1Click:Connect(function()
        F.searchForMatches(matchSearchBox.Text, renderMatchResults)
    end)

    -- ── PROXIMITY BLOCK ──
    F.makeDivider(pgCam, 1048, Color3.fromRGB(0,200,255))
    local proxTitle = F.makeLabel(pgCam, "🚧 PROXIMITY BLOCK", UDim2.new(0,8,0,1054),
        UDim2.new(1,-16,0,18), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Left, 11)
    F.regText(proxTitle)
    F.makeLabel(pgCam, "Invisible wall — you can't walk past this distance from your opponent.",
        UDim2.new(0,8,0,1072), UDim2.new(1,-16,0,16), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 9)

    local proxBtn = F.makeBtn(pgCam, proximityBlockEnabled and "🟢 BLOCK ON" or "🔴 BLOCK OFF",
        UDim2.new(0,8,0,1092), UDim2.new(0,120,0,28),
        proximityBlockEnabled and Color3.fromRGB(60,190,120) or Color3.fromRGB(190,50,50), nil, 10)
    proxBtn.MouseButton1Click:Connect(function()
        proximityBlockEnabled = not proximityBlockEnabled
        proxBtn.Text = proximityBlockEnabled and "🟢 BLOCK ON" or "🔴 BLOCK OFF"
        proxBtn.BackgroundColor3 = proximityBlockEnabled and Color3.fromRGB(60,190,120) or Color3.fromRGB(190,50,50)
        F.notify(proximityBlockEnabled and "Proximity block enabled" or "Proximity block disabled", "info")
    end)

    F.makeLabel(pgCam, "DISTANCE (studs)", UDim2.new(0,8,0,1128), UDim2.new(0,140,0,20), Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local proxDistLbl = F.makeLabel(pgCam, string.format("%.1f", proximityBlockDist),
        UDim2.new(0,320,0,1128), UDim2.new(0,90,0,20), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Right, 11)
    F.regText(proxDistLbl)
    F.makeSlider(pgCam, UDim2.new(0,8,0,1150), UDim2.new(1,-16,0,14), 1, 8, proximityBlockDist, function(v)
        proximityBlockDist = v
        proxDistLbl.Text = string.format("%.1f", v)
    end)

    -- ── FIGHTING SYSTEM ──
    F.makeDivider(pgCam, 1178, Color3.fromRGB(255,80,180))
    local fightTitle = F.makeLabel(pgCam, "⚔ FIGHTING SYSTEM", UDim2.new(0,8,0,1184),
        UDim2.new(1,-16,0,20), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Left, 12)
    F.regText(fightTitle)
    F.makeLabel(pgCam, "Sustained hits push opponent back. Double notes hit harder. Returns to position when done.",
        UDim2.new(0,8,0,1206), UDim2.new(1,-16,0,30), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 9)

    local fightBtn = F.makeBtn(pgCam, "📴  FIGHT MODE OFF", UDim2.new(0,8,0,1240), UDim2.new(1,-16,0,32), Color3.fromRGB(35,35,55), nil, 11)
    fightBtn.MouseButton1Click:Connect(function()
        fightModeEnabled = not fightModeEnabled
        if fightModeEnabled then
            fightBtn.Text = "⚔  FIGHT MODE ON"
            fightBtn.BackgroundColor3 = THEMES[currentThemeName].accent
            F.notify("Fight mode enabled — push your opponent back!", "success")
        else
            fightBtn.Text = "📴  FIGHT MODE OFF"
            fightBtn.BackgroundColor3 = Color3.fromRGB(35,35,55)
            F.deactivateFight()
            F.notify("Fight mode disabled", "info")
        end
    end)

    fightStatusLbl = F.makeLabel(pgCam, "● IDLE", UDim2.new(0,8,0,1278),
        UDim2.new(1,-16,0,18), Color3.fromRGB(160,80,80), Enum.TextXAlignment.Left, 10)

    local fightMomentumLbl = F.makeLabel(pgCam, "YOU: 0.0  |  OPP: 0.0",
        UDim2.new(0,8,0,1298), UDim2.new(1,-16,0,16), Color3.fromRGB(160,160,180), Enum.TextXAlignment.Left, 10)

    F.refreshFightUI = function()
        if FS.active then
            fightStatusLbl.Text = "⚔ FIGHTING"
            fightStatusLbl.TextColor3 = Color3.fromRGB(255,80,80)
        else
            fightStatusLbl.Text = fightModeEnabled and "● READY" or "● IDLE"
            fightStatusLbl.TextColor3 = fightModeEnabled and Color3.fromRGB(80,220,120) or Color3.fromRGB(160,80,80)
        end
        fightMomentumLbl.Text = string.format("YOUR PUSH: %.1f  |  OPP PUSH: %.1f", FS.playerMomentum, FS.opponentMomentum)
    end

    F.makeLabel(pgCam, "HIT POWER", UDim2.new(0,8,0,1324), UDim2.new(0,140,0,20), Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local hitPowerLbl = F.makeLabel(pgCam, string.format("%.1f studs", FS.pushPerHit),
        UDim2.new(0,320,0,1324), UDim2.new(0,90,0,20), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Right, 10)
    F.regText(hitPowerLbl)
    F.makeSlider(pgCam, UDim2.new(0,8,0,1346), UDim2.new(1,-16,0,14), 0.2, 3, FS.pushPerHit, function(v)
        FS.pushPerHit = v
        hitPowerLbl.Text = string.format("%.1f studs", v)
    end)

    F.makeLabel(pgCam, "DOUBLE-NOTE POWER", UDim2.new(0,8,0,1370), UDim2.new(0,160,0,20), Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local dblPowerLbl = F.makeLabel(pgCam, string.format("%.1f studs", FS.pushPerDouble),
        UDim2.new(0,320,0,1370), UDim2.new(0,90,0,20), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Right, 10)
    F.regText(dblPowerLbl)
    F.makeSlider(pgCam, UDim2.new(0,8,0,1392), UDim2.new(1,-16,0,14), 0.5, 5, FS.pushPerDouble, function(v)
        FS.pushPerDouble = v
        dblPowerLbl.Text = string.format("%.1f studs", v)
    end)

    F.makeLabel(pgCam, "MOMENTUM CAP", UDim2.new(0,8,0,1416), UDim2.new(0,140,0,20), Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local momCapLbl = F.makeLabel(pgCam, string.format("%.0f", FS.momentumCap),
        UDim2.new(0,320,0,1416), UDim2.new(0,90,0,20), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Right, 10)
    F.regText(momCapLbl)
    F.makeSlider(pgCam, UDim2.new(0,8,0,1438), UDim2.new(1,-16,0,14), 4, 30, FS.momentumCap, function(v)
        FS.momentumCap = v
        momCapLbl.Text = string.format("%.0f", v)
    end)

    -- ============================================================
    -- ── SILHOUETTE MODE (you + opponent) ──
    -- ============================================================
    local silY = 1466
    F.makeDivider(pgCam, silY, Color3.fromRGB(255,255,255))
    local silTitle = F.makeLabel(pgCam, "🖤 SILHOUETTE MODE", UDim2.new(0,8,0,silY+6),
        UDim2.new(1,-16,0,20), Color3.fromRGB(255,255,255), Enum.TextXAlignment.Left, 12)
    silTitle.Font = Enum.Font.GothamBold
    F.makeLabel(pgCam, "World washes white — you and your opponent become flat black cut-outs.",
        UDim2.new(0,8,0,silY+26), UDim2.new(1,-16,0,16), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 9)

    local silBtn = F.makeBtn(pgCam, "○ SILHOUETTE OFF", UDim2.new(0,8,0,silY+46),
        UDim2.new(0,200,0,28), Color3.fromRGB(35,35,55), nil, 10)
    silBtn.MouseButton1Click:Connect(function() Sil.set(not silhouetteActive) end)

    F.makeLabel(pgCam, "KEY", UDim2.new(0,216,0,silY+46), UDim2.new(0,30,0,28),
        Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local silKeyBtn = F.makeBtn(pgCam, silhouetteKey, UDim2.new(0,248,0,silY+46),
        UDim2.new(0,60,0,28), Color3.fromRGB(25,35,48), nil, 11)
    silKeyBtn.MouseButton1Click:Connect(function()
        silKeyBtn.Text = "..."; silKeyBtn.BackgroundColor3 = Color3.fromRGB(0,200,255)
        local conn; conn = F.own(UserInputService.InputBegan:Connect(function(inp)
            if inp.KeyCode and inp.KeyCode.Name ~= "Unknown" and not inp.KeyCode.Name:match("Mouse") then
                silhouetteKey = inp.KeyCode.Name
                silKeyBtn.Text = silhouetteKey
                silKeyBtn.BackgroundColor3 = Color3.fromRGB(25,35,48)
                conn:Disconnect()
            end
        end))
    end)

    -- who gets blacked out
    local silMeBtn  = F.makeBtn(pgCam, "🧍 YOU: ON", UDim2.new(0,8,0,silY+80),
        UDim2.new(0,116,0,26), Color3.fromRGB(60,190,120), nil, 9)
    local silOppBtn = F.makeBtn(pgCam, "🎤 OPPONENT: ON", UDim2.new(0,130,0,silY+80),
        UDim2.new(0,146,0,26), Color3.fromRGB(60,190,120), nil, 9)
    local silTopBtn = F.makeBtn(pgCam, "👁 ON TOP", UDim2.new(0,282,0,silY+80),
        UDim2.new(0,110,0,26), Color3.fromRGB(70,120,255), nil, 9)

    silMeBtn.MouseButton1Click:Connect(function()
        SilFX.includePlayer = not SilFX.includePlayer
        silMeBtn.Text = SilFX.includePlayer and "🧍 YOU: ON" or "🧍 YOU: OFF"
        silMeBtn.BackgroundColor3 = SilFX.includePlayer and Color3.fromRGB(60,190,120) or Color3.fromRGB(190,50,50)
    end)
    silOppBtn.MouseButton1Click:Connect(function()
        SilFX.includeOpponent = not SilFX.includeOpponent
        silOppBtn.Text = SilFX.includeOpponent and "🎤 OPPONENT: ON" or "🎤 OPPONENT: OFF"
        silOppBtn.BackgroundColor3 = SilFX.includeOpponent and Color3.fromRGB(60,190,120) or Color3.fromRGB(190,50,50)
    end)
    silTopBtn.MouseButton1Click:Connect(function()
        SilFX.alwaysOnTop = not SilFX.alwaysOnTop
        silTopBtn.Text = SilFX.alwaysOnTop and "👁 ON TOP" or "👁 OCCLUDED"
        silTopBtn.BackgroundColor3 = SilFX.alwaysOnTop and Color3.fromRGB(70,120,255) or Color3.fromRGB(35,35,55)
    end)

    -- strength
    F.makeLabel(pgCam, "STRENGTH", UDim2.new(0,8,0,silY+114), UDim2.new(0,110,0,20),
        Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local silStrLbl = F.makeLabel(pgCam, string.format("%d%%", math.floor(SilFX.strength*100 + 0.5)),
        UDim2.new(0,320,0,silY+114), UDim2.new(0,90,0,20), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Right, 10)
    F.regText(silStrLbl)
    F.makeSlider(pgCam, UDim2.new(0,8,0,silY+136), UDim2.new(1,-16,0,14), 0.2, 1, SilFX.strength, function(v)
        SilFX.strength = v
        silStrLbl.Text = string.format("%d%%", math.floor(v*100 + 0.5))
    end)

    -- cut-out colour
    F.makeLabel(pgCam, "CUT-OUT COLOR", UDim2.new(0,8,0,silY+158), UDim2.new(0,140,0,20),
        Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local silColors = {
        { name = "BLACK",  c = Color3.new(0,0,0) },
        { name = "WHITE",  c = Color3.new(1,1,1) },
        { name = "ACCENT", c = nil },
    }
    for ci, entry in ipairs(silColors) do
        local cx = 150 + (ci-1) * 84
        local cbtn = F.makeBtn(pgCam, entry.name, UDim2.new(0,cx,0,silY+158), UDim2.new(0,80,0,22),
            entry.c or THEMES[currentThemeName].accent, Color3.fromRGB(20,20,20), 9)
        cbtn.MouseButton1Click:Connect(function()
            SilFX.fillColor = entry.c or THEMES[currentThemeName].accent
            F.notify("Silhouette color: " .. entry.name, "info")
        end)
    end

    F.refreshSilUI = function()
        if not silBtn or not silBtn.Parent then return end
        silBtn.Text = silhouetteActive and "🖤 SILHOUETTE ON" or "○ SILHOUETTE OFF"
        silBtn.BackgroundColor3 = silhouetteActive and Color3.fromRGB(20,20,20) or Color3.fromRGB(35,35,55)
    end
    F.refreshSilUI()

    -- ── INTRO TRANSITIONS ──
    local introY = silY + 200
    F.makeDivider(pgCam, introY, Color3.fromRGB(255,200,60))
    F.makeLabel(pgCam, "🎬 INTRO TRANSITIONS", UDim2.new(0,8,0,introY+6),
        UDim2.new(1,-16,0,18), Color3.fromRGB(255,200,60), Enum.TextXAlignment.Left, 11)
    F.makeLabel(pgCam, "Play a cinematic intro before a song starts. Click any to preview.",
        UDim2.new(0,8,0,introY+24), UDim2.new(1,-16,0,16), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 9)

    local introData = {
        { name = "COUNTDOWN", label = "🔢 3-2-1-GO!", desc = "Classic FNF countdown" },
        { name = "WIPE",      label = "🔲 DIAGONAL WIPE", desc = "Black screen slides away" },
        { name = "PIXELATE",  label = "🟦 PIXEL DISSOLVE", desc = "Pixelated grid dissolves" },
        { name = "FLASH",     label = "⚡ FLASH BANG", desc = "White flash then reveal" },
        { name = "SPLIT",     label = "⚔ VS SPLIT", desc = "Curtains split open with VS" },
    }

    for i, intro in ipairs(introData) do
        local iy = introY + 46 + (i-1) * 38
        local introBtn = F.makeBtn(pgCam, intro.label, UDim2.new(0,8,0,iy), UDim2.new(0,200,0,32), Color3.fromRGB(35,35,55), nil, 10)
        F.makeLabel(pgCam, intro.desc, UDim2.new(0,216,0,iy), UDim2.new(1,-224,0,32), Color3.fromRGB(120,120,140), Enum.TextXAlignment.Left, 9)
        introBtn.MouseButton1Click:Connect(function()
            F.playIntroTransition(intro.name)
            F.notify("Playing: " .. intro.label, "info")
        end)
    end
    -- ============================================================
    -- ── CHAOS CAMERA (music-video / edit mode) ──
    -- ============================================================
    local chaosY = introY + 250
    F.makeDivider(pgCam, chaosY, Color3.fromRGB(255,60,60))
    local chTitle = F.makeLabel(pgCam, "CHAOS CAMERA", UDim2.new(0,8,0,chaosY+6),
        UDim2.new(1,-16,0,20), Color3.fromRGB(255,60,60), Enum.TextXAlignment.Left, 12)
    chTitle.Font = Enum.Font.GothamBold
    F.makeLabel(pgCam, "Violent punch zooms, irregular shake, roll, tearing and RGB split. Needs the cinematic camera ON.",
        UDim2.new(0,8,0,chaosY+26), UDim2.new(1,-16,0,28), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 9)

    local chBtn = F.makeBtn(pgCam, "CHAOS OFF", UDim2.new(0,8,0,chaosY+58),
        UDim2.new(1,-16,0,32), Color3.fromRGB(35,35,55), nil, 11)
    chBtn.MouseButton1Click:Connect(function()
        Chaos.setEnabled(not Chaos.enabled)
        chBtn.Text = Chaos.enabled and "CHAOS ON — CAMERA IS UNSTABLE" or "CHAOS OFF"
        chBtn.BackgroundColor3 = Chaos.enabled and Color3.fromRGB(200,40,40) or Color3.fromRGB(35,35,55)
        if Chaos.enabled and not FNFCamera.enabled then
            F.notify("Turn the cinematic camera ON or chaos has nothing to drive", "warn")
        end
    end)

    -- presets
    F.makeLabel(pgCam, "PRESET", UDim2.new(0,8,0,chaosY+96), UDim2.new(0,80,0,18),
        Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local chPresets = { "Calm", "Intense", "Chaotic", "Corrupted" }
    local chSliders = {}
    for i, pname in ipairs(chPresets) do
        local px = 8 + (i-1) * 100
        local pb = F.makeBtn(pgCam, pname, UDim2.new(0,px,0,chaosY+116), UDim2.new(0,94,0,26),
            Color3.fromRGB(45,30,60), nil, 9)
        pb.MouseButton1Click:Connect(function()
            Chaos.applyPreset(pname)
            for key, sl in pairs(chSliders) do
                if sl.setValue then sl.setValue(Chaos[key], true) end
            end
        end)
    end

    -- intensity sliders
    local chRows = {
        { key = "master",      label = "MASTER",       min = 0, max = 2 },
        { key = "shake",       label = "SHAKE",        min = 0, max = 2 },
        { key = "zoomPunch",   label = "PUNCH ZOOM",   min = 0, max = 2 },
        { key = "warp",        label = "WARP / LENS",  min = 0, max = 2 },
        { key = "glitch",      label = "GLITCH / TEAR",min = 0, max = 2 },
        { key = "flash",       label = "FLASH / RGB",  min = 0, max = 2 },
        { key = "readability", label = "READABILITY",  min = 0.4, max = 1.6 },
    }
    for i, row in ipairs(chRows) do
        local ry = chaosY + 152 + (i-1) * 44
        F.makeLabel(pgCam, row.label, UDim2.new(0,8,0,ry), UDim2.new(0,150,0,20),
            Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
        local vlbl = F.makeLabel(pgCam, string.format("%.2f", Chaos[row.key]),
            UDim2.new(0,320,0,ry), UDim2.new(0,90,0,20), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Right, 10)
        F.regText(vlbl)
        local capturedKey = row.key
        chSliders[row.key] = F.makeSlider(pgCam, UDim2.new(0,8,0,ry+22), UDim2.new(1,-16,0,14),
            row.min, row.max, Chaos[row.key], function(v)
                Chaos[capturedKey] = v
                vlbl.Text = string.format("%.2f", v)
            end)
    end

    local chBeatY = chaosY + 152 + #chRows * 44
    local chBeatBtn = F.makeBtn(pgCam, Chaos.beatSync and "BEAT SYNC: ON" or "BEAT SYNC: OFF",
        UDim2.new(0,8,0,chBeatY), UDim2.new(0,160,0,26),
        Chaos.beatSync and Color3.fromRGB(60,190,120) or Color3.fromRGB(190,50,50), nil, 9)
    chBeatBtn.MouseButton1Click:Connect(function()
        Chaos.beatSync = not Chaos.beatSync
        chBeatBtn.Text = Chaos.beatSync and "BEAT SYNC: ON" or "BEAT SYNC: OFF"
        chBeatBtn.BackgroundColor3 = Chaos.beatSync and Color3.fromRGB(60,190,120) or Color3.fromRGB(190,50,50)
    end)
    F.makeLabel(pgCam, "Pulses the camera on every beat of the current BPM.",
        UDim2.new(0,176,0,chBeatY), UDim2.new(1,-184,0,26), Color3.fromRGB(120,120,140), Enum.TextXAlignment.Left, 9)

    -- manual triggers
    local chTrigY = chBeatY + 34
    local chImpact = F.makeBtn(pgCam, "IMPACT", UDim2.new(0,8,0,chTrigY), UDim2.new(0,126,0,28), Color3.fromRGB(200,40,40), nil, 10)
    local chGlitch = F.makeBtn(pgCam, "GLITCH", UDim2.new(0,140,0,chTrigY), UDim2.new(0,126,0,28), Color3.fromRGB(140,40,180), nil, 10)
    local chTunnel = F.makeBtn(pgCam, "TUNNEL", UDim2.new(0,272,0,chTrigY), UDim2.new(0,126,0,28), Color3.fromRGB(40,120,220), nil, 10)
    chImpact.MouseButton1Click:Connect(function() Chaos.bigImpact(1.8) end)
    chGlitch.MouseButton1Click:Connect(function() Chaos.glitchBurst(0.4) end)
    chTunnel.MouseButton1Click:Connect(function() Chaos.tunnelPull(0.9) end)
    -- ============================================================
    -- ── CINEMATIC BARS + FULL POWER ──
    -- ============================================================
    local extraY = chTrigY + 58
    F.makeDivider(pgCam, extraY, Color3.fromRGB(255,200,60))

    local barsBtn = F.makeBtn(pgCam, "CINEMATIC BARS: ON", UDim2.new(0,8,0,extraY+10),
        UDim2.new(0,220,0,28), Color3.fromRGB(60,190,120), nil, 10)
    barsBtn.MouseButton1Click:Connect(function()
        CAM_CFG.BarsEnabled = not CAM_CFG.BarsEnabled
        barsBtn.Text = CAM_CFG.BarsEnabled and "CINEMATIC BARS: ON" or "CINEMATIC BARS: OFF"
        barsBtn.BackgroundColor3 = CAM_CFG.BarsEnabled and Color3.fromRGB(60,190,120) or Color3.fromRGB(190,50,50)
        if not CAM_CFG.BarsEnabled then
            if FNFCamera.letterTop then FNFCamera.letterTop.Size = UDim2.new(1,0,0,0) end
            if FNFCamera.letterBottom then FNFCamera.letterBottom.Size = UDim2.new(1,0,0,0) end
        end
        F.notify(CAM_CFG.BarsEnabled and "Letterbox bars on" or "Letterbox bars off", "info")
    end)

    local fullBtn = F.makeBtn(pgCam, "FULL POWER (100%)", UDim2.new(0,236,0,extraY+10),
        UDim2.new(0,166,0,28), Color3.fromRGB(200,40,40), nil, 10)
    fullBtn.MouseButton1Click:Connect(function()
        FNFCamera:SetEnabled(true)
        FNFCamera:SetSensitivity(3)
        FNFCamera:SetShakeScale(1)
        FNFCamera:SetZoomScale(1)
        FNFCamera.targetIntensity = 1
        FNFCamera.intensity = 1
        camBtn.Text = "CAMERA ON"
        camBtn.BackgroundColor3 = THEMES[currentThemeName].accent
        F.notify("Cinematic camera at 100% — max shake, zoom and sensitivity", "success")
    end)

    -- ============================================================
    -- ── SPLIT SCREEN ──
    -- ============================================================
    local spY = extraY + 50
    F.makeDivider(pgCam, spY, Color3.fromRGB(255,110,230))
    local spTitle = F.makeLabel(pgCam, "SPLIT SCREEN", UDim2.new(0,8,0,spY+6),
        UDim2.new(1,-16,0,20), Color3.fromRGB(255,110,230), Enum.TextXAlignment.Left, 12)
    spTitle.Font = Enum.Font.GothamBold
    F.makeLabel(pgCam, "You left, opponent right, turned to face each other. Both cameras stay locked still.",
        UDim2.new(0,8,0,spY+26), UDim2.new(1,-16,0,28), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 9)
    F.makeLabel(pgCam, "Roblox renders the world through one camera, so these panes show cloned characters only - no map behind them.",
        UDim2.new(0,8,0,spY+54), UDim2.new(1,-16,0,28), Color3.fromRGB(200,140,60), Enum.TextXAlignment.Left, 9)

    local spBtn = F.makeBtn(pgCam, "SPLIT SCREEN OFF", UDim2.new(0,8,0,spY+86),
        UDim2.new(0,250,0,32), Color3.fromRGB(35,35,55), nil, 11)
    spBtn.MouseButton1Click:Connect(function() Split.setEnabled(not Split.enabled) end)

    F.makeLabel(pgCam, "KEY", UDim2.new(0,266,0,spY+86), UDim2.new(0,30,0,32),
        Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local spKeyBtn = F.makeBtn(pgCam, Split.key, UDim2.new(0,298,0,spY+86),
        UDim2.new(0,64,0,32), Color3.fromRGB(25,35,48), nil, 11)
    spKeyBtn.MouseButton1Click:Connect(function()
        spKeyBtn.Text = "..."; spKeyBtn.BackgroundColor3 = Color3.fromRGB(0,200,255)
        local conn; conn = F.own(UserInputService.InputBegan:Connect(function(inp)
            if inp.KeyCode and inp.KeyCode.Name ~= "Unknown" and not inp.KeyCode.Name:match("Mouse") then
                Split.key = inp.KeyCode.Name
                spKeyBtn.Text = Split.key
                spKeyBtn.BackgroundColor3 = Color3.fromRGB(25,35,48)
                conn:Disconnect()
            end
        end))
    end)

    Split.refreshUI = function()
        if not spBtn or not spBtn.Parent then return end
        spBtn.Text = Split.enabled and "SPLIT SCREEN ON" or "SPLIT SCREEN OFF"
        spBtn.BackgroundColor3 = Split.enabled and Color3.fromRGB(200,60,160) or Color3.fromRGB(35,35,55)
    end
    Split.refreshUI()

    local spRefresh = F.makeBtn(pgCam, "REBUILD CLONES", UDim2.new(0,8,0,spY+126),
        UDim2.new(0,180,0,26), Color3.fromRGB(70,120,255), nil, 9)
    spRefresh.MouseButton1Click:Connect(function()
        if Split.gui then Split.refreshClones(); F.notify("Split clones rebuilt", "info")
        else F.notify("Turn split screen on first", "warn") end
    end)

    local spFace = F.makeBtn(pgCam, "FACE EACH OTHER", UDim2.new(0,196,0,spY+126),
        UDim2.new(0,100,0,26), Color3.fromRGB(60,190,120), nil, 9)
    spFace.MouseButton1Click:Connect(function()
        Split.rotL, Split.rotR = -65, 65
        Split.reface()
        if Split.refreshRots then Split.refreshRots() end
    end)

    local spLoop = F.makeBtn(pgCam, "LOOP MIRRORED: ON", UDim2.new(0,8,0,spY+158),
        UDim2.new(0,190,0,26), Color3.fromRGB(60,190,120), nil, 9)
    spLoop.MouseButton1Click:Connect(function()
        Split.loopMirrored = not Split.loopMirrored
        spLoop.Text = Split.loopMirrored and "LOOP MIRRORED: ON" or "LOOP MIRRORED: OFF"
        spLoop.BackgroundColor3 = Split.loopMirrored and Color3.fromRGB(60,190,120) or Color3.fromRGB(190,50,50)
    end)

    local spFront = F.makeBtn(pgCam, "FACE FRONT", UDim2.new(0,304,0,spY+126),
        UDim2.new(0,98,0,26), Color3.fromRGB(70,120,255), nil, 9)
    spFront.MouseButton1Click:Connect(function()
        Split.rotL, Split.rotR = 0, 0
        Split.reface()
        if Split.refreshRots then Split.refreshRots() end
    end)

    local spSliders, spLabels = {}, {}
    Split.refreshRots = function()
        for k, sl in pairs(spSliders) do
            if sl.setValue then sl.setValue(Split[k], false) end
            if spLabels[k] then spLabels[k].Text = string.format("%.1f", Split[k]) end
        end
    end

    local spRows = {
        { key = "dist",      label = "CAMERA DISTANCE", min = 3,  max = 14 },
        { key = "height",    label = "CAMERA HEIGHT",   min = -1, max = 6  },
        { key = "rotL",      label = "YOUR ROTATION",   min = -180, max = 180 },
        { key = "rotR",      label = "OPP ROTATION",    min = -180, max = 180 },
    }
    for i, row in ipairs(spRows) do
        local ry = spY + 196 + (i-1) * 44
        F.makeLabel(pgCam, row.label, UDim2.new(0,8,0,ry), UDim2.new(0,200,0,20),
            Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
        local vlbl = F.makeLabel(pgCam, string.format("%.1f", Split[row.key]),
            UDim2.new(0,320,0,ry), UDim2.new(0,90,0,20), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Right, 10)
        F.regText(vlbl)
        local capturedKey = row.key
        spLabels[row.key] = vlbl
        spSliders[row.key] = F.makeSlider(pgCam, UDim2.new(0,8,0,ry+22), UDim2.new(1,-16,0,14),
            row.min, row.max, Split[row.key], function(v)
                Split[capturedKey] = v
                vlbl.Text = string.format("%.1f", v)
                if capturedKey == "rotL" or capturedKey == "rotR" then Split.reface() end
            end)
    end
    -- ============================================================
    -- ── HEALTH BAR ──
    -- ============================================================
    local hbY = spY + 390
    F.makeDivider(pgCam, hbY, Color3.fromRGB(60,230,120))
    local hbTitle = F.makeLabel(pgCam, "HEALTH BAR", UDim2.new(0,8,0,hbY+6),
        UDim2.new(1,-16,0,20), Color3.fromRGB(60,230,120), Enum.TextXAlignment.Left, 12)
    hbTitle.Font = Enum.Font.GothamBold
    F.makeLabel(pgCam, "Your notes push you forward, their poses push you back. Icon position shows how close you are to losing.",
        UDim2.new(0,8,0,hbY+26), UDim2.new(1,-16,0,28), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 9)

    local hbBtn = F.makeBtn(pgCam, "HEALTH BAR ON", UDim2.new(0,8,0,hbY+58),
        UDim2.new(0,250,0,32), Color3.fromRGB(40,170,90), nil, 11)
    hbBtn.MouseButton1Click:Connect(function() Health.setEnabled(not Health.enabled) end)

    F.makeLabel(pgCam, "KEY", UDim2.new(0,266,0,hbY+58), UDim2.new(0,30,0,32),
        Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local hbKeyBtn = F.makeBtn(pgCam, Health.key, UDim2.new(0,298,0,hbY+58),
        UDim2.new(0,64,0,32), Color3.fromRGB(25,35,48), nil, 11)
    hbKeyBtn.MouseButton1Click:Connect(function()
        hbKeyBtn.Text = "..."; hbKeyBtn.BackgroundColor3 = Color3.fromRGB(0,200,255)
        local conn; conn = F.own(UserInputService.InputBegan:Connect(function(inp)
            if inp.KeyCode and inp.KeyCode.Name ~= "Unknown" and not inp.KeyCode.Name:match("Mouse") then
                Health.key = inp.KeyCode.Name
                hbKeyBtn.Text = Health.key
                hbKeyBtn.BackgroundColor3 = Color3.fromRGB(25,35,48)
                conn:Disconnect()
            end
        end))
    end)

    Health.refreshUI = function()
        if not hbBtn or not hbBtn.Parent then return end
        hbBtn.Text = Health.enabled and "HEALTH BAR ON" or "HEALTH BAR OFF"
        hbBtn.BackgroundColor3 = Health.enabled and Color3.fromRGB(40,170,90) or Color3.fromRGB(35,35,55)
    end
    Health.refreshUI()

    local hbSync = F.makeBtn(pgCam, Health.syncRoblox and "ROBLOX HEALTH SYNC: ON" or "ROBLOX HEALTH SYNC: OFF",
        UDim2.new(0,196,0,hbY+98), UDim2.new(0,200,0,26),
        Health.syncRoblox and Color3.fromRGB(60,190,120) or Color3.fromRGB(35,35,55), nil, 9)
    hbSync.MouseButton1Click:Connect(function()
        Health.syncRoblox = not Health.syncRoblox
        hbSync.Text = Health.syncRoblox and "ROBLOX HEALTH SYNC: ON" or "ROBLOX HEALTH SYNC: OFF"
        hbSync.BackgroundColor3 = Health.syncRoblox and Color3.fromRGB(60,190,120) or Color3.fromRGB(35,35,55)
        if not Health.syncRoblox then Health.releaseRoblox() end
        F.notify(Health.syncRoblox and "Your Roblox health now follows the rap battle"
            or "Roblox health released", "info")
    end)

    local hbDmg = F.makeBtn(pgCam, Health.respectDamage and "RESPECT GAME DAMAGE: ON" or "RESPECT GAME DAMAGE: OFF",
        UDim2.new(0,8,0,hbY+130), UDim2.new(0,200,0,26),
        Health.respectDamage and Color3.fromRGB(60,190,120) or Color3.fromRGB(35,35,55), nil, 9)
    hbDmg.MouseButton1Click:Connect(function()
        Health.respectDamage = not Health.respectDamage
        hbDmg.Text = Health.respectDamage and "RESPECT GAME DAMAGE: ON" or "RESPECT GAME DAMAGE: OFF"
        hbDmg.BackgroundColor3 = Health.respectDamage and Color3.fromRGB(60,190,120) or Color3.fromRGB(35,35,55)
    end)
    local hbVig = F.makeBtn(pgCam, Health.lowVignette and "RED VIGNETTE: ON" or "RED VIGNETTE: OFF",
        UDim2.new(0,214,0,hbY+130), UDim2.new(0,182,0,26),
        Health.lowVignette and Color3.fromRGB(190,40,50) or Color3.fromRGB(35,35,55), nil, 9)
    hbVig.MouseButton1Click:Connect(function()
        Health.lowVignette = not Health.lowVignette
        hbVig.Text = Health.lowVignette and "RED VIGNETTE: ON" or "RED VIGNETTE: OFF"
        hbVig.BackgroundColor3 = Health.lowVignette and Color3.fromRGB(190,40,50) or Color3.fromRGB(35,35,55)
    end)
    F.makeLabel(pgCam, "Rap drain stops at 1 HP. Shows on your screen only.",
        UDim2.new(0,8,0,hbY+158), UDim2.new(1,-16,0,16), Color3.fromRGB(120,120,140), Enum.TextXAlignment.Left, 9)

    local hbReset = F.makeBtn(pgCam, "RESET TO 50%", UDim2.new(0,8,0,hbY+98),
        UDim2.new(0,180,0,26), Color3.fromRGB(70,120,255), nil, 9)
    hbReset.MouseButton1Click:Connect(function() Health.reset() end)

    -- optional custom icons
    F.makeLabel(pgCam, "YOUR ICON ID", UDim2.new(0,8,0,hbY+180), UDim2.new(0,110,0,24),
        Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 9)
    local hbIconP = F.makeBox(pgCam, UDim2.new(0,120,0,hbY+180), UDim2.new(0,120,0,24), "decal id or bf", Health.playerIcon)
    F.makeLabel(pgCam, "THEIR ICON", UDim2.new(0,248,0,hbY+180), UDim2.new(0,90,0,24),
        Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 9)
    local hbIconO = F.makeBox(pgCam, UDim2.new(0,330,0,hbY+180), UDim2.new(0,72,0,24), "id or dad", Health.oppIcon)
    -- a box takes a decal ID or the name of an imported FNF icon
    local function applyIcons()
        local p, o = Health.cleanIcon(hbIconP.Text), Health.cleanIcon(hbIconO.Text)
        hbIconP.Text, hbIconO.Text = p, o
        Health.setIcons(p, o)
        for _, name in ipairs({ p, o }) do
            if string.match(name, "^%a") and not Skin.icon(name, "O", false) then
                local have = Skin.iconNames()
                F.notify("No FNF icon called \"" .. name .. "\""
                    .. (have ~= "" and (". Try: " .. have) or " — the sprites folder has no icons"), "warn")
            end
        end
    end
    hbIconP.FocusLost:Connect(applyIcons)
    hbIconO.FocusLost:Connect(applyIcons)

    local hbRows = {
        { key = "gainPerNote",  label = "GAIN PER NOTE",    min = 0,    max = 0.15 },
        { key = "drainPerPose", label = "DRAIN PER POSE",   min = 0,    max = 0.2  },
        { key = "passiveDrain", label = "PASSIVE DRAIN /s", min = 0,    max = 0.08 },
        { key = "smooth",       label = "BAR SMOOTHING",    min = 2,    max = 18   },
        { key = "vignetteAt",   label = "VIGNETTE STARTS BELOW", min = 0.05, max = 0.6 },
        { key = "holdRate",     label = "HOLD: HEALTH /s AT START (0 = off)", min = 0, max = 0.15 },
        { key = "holdCurve",    label = "HOLD: HOW FAST IT SPEEDS UP", min = 0, max = 4 },
        { key = "holdMax",      label = "HOLD: MOST HEALTH /s",  min = 0.02, max = 0.6 },
    }
    for i, row in ipairs(hbRows) do
        local ry = hbY + 216 + (i-1) * 44
        F.makeLabel(pgCam, row.label, UDim2.new(0,8,0,ry), UDim2.new(0,200,0,20),
            Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
        local vlbl = F.makeLabel(pgCam, string.format("%.3f", Health[row.key]),
            UDim2.new(0,320,0,ry), UDim2.new(0,90,0,20), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Right, 10)
        F.regText(vlbl)
        local ck = row.key
        F.makeSlider(pgCam, UDim2.new(0,8,0,ry+22), UDim2.new(1,-16,0,14),
            row.min, row.max, Health[row.key], function(v)
                Health[ck] = v
                vlbl.Text = string.format("%.3f", v)
            end)
    end

    -- ============================================================
    -- ── PERFECT DOUBLE NOTE ──
    -- ============================================================
    local pdY = hbY + 216 + #hbRows * 44 + 10
    F.makeDivider(pgCam, pdY, Color3.fromRGB(120,240,255))
    local pdTitle = F.makeLabel(pgCam, "PERFECT DOUBLE NOTE", UDim2.new(0,8,0,pdY+6),
        UDim2.new(1,-16,0,20), Color3.fromRGB(120,240,255), Enum.TextXAlignment.Left, 12)
    pdTitle.Font = Enum.Font.GothamBold
    F.makeLabel(pgCam, "Hit two different notes inside the window and an afterimage of you flies off in that note's direction.",
        UDim2.new(0,8,0,pdY+26), UDim2.new(1,-16,0,28), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 9)
    F.makeLabel(pgCam, "Input fires once per frame, so the tightest window that can actually trigger is about 16ms at 60fps.",
        UDim2.new(0,8,0,pdY+54), UDim2.new(1,-16,0,28), Color3.fromRGB(200,140,60), Enum.TextXAlignment.Left, 9)

    local pdBtn = F.makeBtn(pgCam, "AFTERIMAGE ON", UDim2.new(0,8,0,pdY+86),
        UDim2.new(0,200,0,30), Color3.fromRGB(40,150,200), nil, 10)
    pdBtn.MouseButton1Click:Connect(function()
        Ghost.enabled = not Ghost.enabled
        pdBtn.Text = Ghost.enabled and "AFTERIMAGE ON" or "AFTERIMAGE OFF"
        pdBtn.BackgroundColor3 = Ghost.enabled and Color3.fromRGB(40,150,200) or Color3.fromRGB(35,35,55)
    end)

    local pdTest = F.makeBtn(pgCam, "TEST GHOST", UDim2.new(0,216,0,pdY+86),
        UDim2.new(0,186,0,30), Color3.fromRGB(140,40,180), nil, 10)
    pdTest.MouseButton1Click:Connect(function()
        Ghost.spawn(ARROW_ORDER[math.random(1, #ARROW_ORDER)])
    end)

    -- zoom power lives on the camera, so it gets its own row
    F.makeLabel(pgCam, "DOUBLE-NOTE ZOOM", UDim2.new(0,8,0,pdY+122), UDim2.new(0,220,0,20),
        Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local pdZoomLbl = F.makeLabel(pgCam, string.format("%.0f", FNFCamera.dnPower),
        UDim2.new(0,320,0,pdY+122), UDim2.new(0,90,0,20), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Right, 10)
    F.regText(pdZoomLbl)
    F.makeSlider(pgCam, UDim2.new(0,8,0,pdY+144), UDim2.new(1,-16,0,14), 0, 120, FNFCamera.dnPower, function(v)
        FNFCamera.dnPower = v
        pdZoomLbl.Text = string.format("%.0f", v)
    end)

    local pdRows = {
        { key = "window",   label = "PERFECT WINDOW (s)", min = 0.005, max = 0.12, fmt = "%.3f" },
        { key = "life",     label = "AFTERIMAGE LIFE (s)",min = 0.15,  max = 1.5,  fmt = "%.2f" },
        { key = "distance", label = "TRAVEL DISTANCE",    min = 1,     max = 20,   fmt = "%.1f" },
    }
    for i, row in ipairs(pdRows) do
        local ry = pdY + 170 + (i-1) * 44
        F.makeLabel(pgCam, row.label, UDim2.new(0,8,0,ry), UDim2.new(0,220,0,20),
            Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
        local vlbl = F.makeLabel(pgCam, string.format(row.fmt, Ghost[row.key]),
            UDim2.new(0,320,0,ry), UDim2.new(0,90,0,20), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Right, 10)
        F.regText(vlbl)
        local ck, cf2 = row.key, row.fmt
        F.makeSlider(pgCam, UDim2.new(0,8,0,ry+22), UDim2.new(1,-16,0,14),
            row.min, row.max, Ghost[row.key], function(v)
                Ghost[ck] = v
                vlbl.Text = string.format(cf2, v)
            end)
    end
    -- ── FE DASH: the afterimage other players see ──
    local fdY = pdY + 170 + #pdRows * 44 + 4
    do
        F.makeLabel(pgCam, "The ghost is only on your screen: FE never sends a clone your client makes to anyone. Your own position does reach everyone, so FE DASH moves the real you along the ghost's path for a moment and back. Other players see that.",
            UDim2.new(0,8,0,fdY), UDim2.new(1,-16,0,40), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 9).TextWrapped = true
        local dashBtn = F.makeBtn(pgCam, "", UDim2.new(0,8,0,fdY+44), UDim2.new(0,200,0,30), Color3.fromRGB(35,35,55), nil, 10)
        local styleBtn = F.makeBtn(pgCam, "", UDim2.new(0,216,0,fdY+44), UDim2.new(0,186,0,30), Color3.fromRGB(70,120,255), nil, 10)
        local function paint()
            dashBtn.Text = Ghost.feDash and "FE DASH ON" or "FE DASH OFF"
            dashBtn.BackgroundColor3 = Ghost.feDash and Color3.fromRGB(40,150,200) or Color3.fromRGB(35,35,55)
            styleBtn.Text = "STYLE: " .. Ghost.dashStyle
        end
        paint()
        dashBtn.MouseButton1Click:Connect(function()
            Ghost.feDash = not Ghost.feDash
            paint()
            if Ghost.feDash then
                F.notify("Some games pull you back or kick for sudden moves: keep it short, or use SLIDE", "warn")
            end
        end)
        styleBtn.MouseButton1Click:Connect(function()
            Ghost.dashStyle = (Ghost.dashStyle == "TELEPORT") and "SLIDE" or "TELEPORT"
            paint()
        end)
        local dashRows = {
            { key = "dashDistance", label = "DASH DISTANCE (studs)", min = 1,    max = 10,  fmt = "%.1f" },
            { key = "dashHold",     label = "TIME AWAY (s)",          min = 0.05, max = 0.6, fmt = "%.2f" },
        }
        for i, row in ipairs(dashRows) do
            local ry = fdY + 82 + (i-1) * 44
            F.makeLabel(pgCam, row.label, UDim2.new(0,8,0,ry), UDim2.new(0,220,0,20),
                Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
            local vlbl = F.makeLabel(pgCam, string.format(row.fmt, Ghost[row.key]),
                UDim2.new(0,320,0,ry), UDim2.new(0,90,0,20), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Right, 10)
            F.regText(vlbl)
            local ck, cf2 = row.key, row.fmt
            F.makeSlider(pgCam, UDim2.new(0,8,0,ry+22), UDim2.new(1,-16,0,14),
                row.min, row.max, Ghost[row.key], function(v)
                    Ghost[ck] = v
                    vlbl.Text = string.format(cf2, v)
                end)
        end
    end
    -- ============================================================
    -- ── CINEMATIC PRESETS ──
    -- ============================================================
    local cpY = fdY + 82 + 2 * 44 + 10
    F.makeDivider(pgCam, cpY, Color3.fromRGB(255,200,60))
    local cpTitle = F.makeLabel(pgCam, "CINEMATIC PRESETS", UDim2.new(0,8,0,cpY+6),
        UDim2.new(1,-16,0,20), Color3.fromRGB(255,200,60), Enum.TextXAlignment.Left, 12)
    cpTitle.Font = Enum.Font.GothamBold

    local syncSnapRef = nil
    local cpDesc = F.makeLabel(pgCam, CAM_PRESETS[FNFCamera.preset] and CAM_PRESETS[FNFCamera.preset].desc or "",
        UDim2.new(0,8,0,cpY+26), UDim2.new(1,-16,0,28), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 9)

    local cpBtns = {}
    for i, pname in ipairs(CAM_PRESET_ORDER) do
        local col = (i - 1) % 3
        local rowN = math.floor((i - 1) / 3)
        local pb = F.makeBtn(pgCam, pname,
            UDim2.new(0, 8 + col * 132, 0, cpY + 58 + rowN * 34),
            UDim2.new(0, 126, 0, 30),
            pname == FNFCamera.preset and Color3.fromRGB(255,160,40) or Color3.fromRGB(45,35,55), nil, 10)
        cpBtns[pname] = pb
        pb.MouseButton1Click:Connect(function()
            FNFCamera:ApplyPreset(pname)
            if syncSnapRef then syncSnapRef() end
            cpDesc.Text = CAM_PRESETS[pname].desc
            for n, b in pairs(cpBtns) do
                b.BackgroundColor3 = (n == pname) and Color3.fromRGB(255,160,40) or Color3.fromRGB(45,35,55)
            end
            distLbl.Text  = string.format("%.0f", FNFCamera.camDistance)
            heightLbl.Text = string.format("%.1f", FNFCamera.camHeight)
            fovLbl.Text   = string.format("%.0f", CAM_CFG.BaseFOV)
            F.notify("Camera preset: " .. pname, "success")
        end)
    end

    -- hotkeys drive the same buttons, so mirror the highlight
    Keys.onPreset = function(pname)
        if not CAM_PRESETS[pname] then return end
        if syncSnapRef then syncSnapRef() end
        cpDesc.Text = CAM_PRESETS[pname].desc
        for n, b in pairs(cpBtns) do
            b.BackgroundColor3 = (n == pname) and Color3.fromRGB(255,160,40) or Color3.fromRGB(45,35,55)
        end
        distLbl.Text = string.format("%.0f", FNFCamera.camDistance)
        heightLbl.Text = string.format("%.1f", FNFCamera.camHeight)
        fovLbl.Text = string.format("%.0f", CAM_CFG.BaseFOV)
    end

    -- settle controls
    local cpSetY = cpY + 58 + math.ceil(#CAM_PRESET_ORDER / 3) * 34 + 8
    local cpSettleBtn = F.makeBtn(pgCam,
        FNFCamera.settleEnabled and "SETTLE WHEN QUIET: ON" or "SETTLE WHEN QUIET: OFF",
        UDim2.new(0,8,0,cpSetY), UDim2.new(0,220,0,26),
        FNFCamera.settleEnabled and Color3.fromRGB(60,190,120) or Color3.fromRGB(190,50,50), nil, 9)
    cpSettleBtn.MouseButton1Click:Connect(function()
        FNFCamera.settleEnabled = not FNFCamera.settleEnabled
        cpSettleBtn.Text = FNFCamera.settleEnabled and "SETTLE WHEN QUIET: ON" or "SETTLE WHEN QUIET: OFF"
        cpSettleBtn.BackgroundColor3 = FNFCamera.settleEnabled and Color3.fromRGB(60,190,120) or Color3.fromRGB(190,50,50)
    end)
    F.makeLabel(pgCam, "Locks the frame in place once both of you stop.",
        UDim2.new(0,236,0,cpSetY), UDim2.new(1,-244,0,26), Color3.fromRGB(120,120,140), Enum.TextXAlignment.Left, 9)

    -- beat zoom
    local cpBeat = F.makeBtn(pgCam, "BEAT ZOOM: OFF", UDim2.new(0,8,0,cpSetY+60),
        UDim2.new(0,190,0,26), Color3.fromRGB(35,35,55), nil, 9)
    local function syncBeatBtn()
        cpBeat.Text = FNFCamera.beatZoom and "BEAT ZOOM: ON" or "BEAT ZOOM: OFF"
        cpBeat.BackgroundColor3 = FNFCamera.beatZoom and Color3.fromRGB(255,160,40) or Color3.fromRGB(35,35,55)
    end
    cpBeat.MouseButton1Click:Connect(function()
        FNFCamera:SetBeatZoom(not FNFCamera.beatZoom)
        syncBeatBtn()
    end)
    Keys.onBeatZoom = syncBeatBtn
    syncBeatBtn()
    F.makeLabel(pgCam, "Pulses every beat, heavier on every 4th.",
        UDim2.new(0,206,0,cpSetY+60), UDim2.new(1,-214,0,26), Color3.fromRGB(120,120,140), Enum.TextXAlignment.Left, 9)

    -- upgraded follow toggles
    local cpSpring = F.makeBtn(pgCam, "SPRING FOLLOW: ON", UDim2.new(0,8,0,cpSetY+30),
        UDim2.new(0,190,0,26), Color3.fromRGB(60,190,120), nil, 9)
    cpSpring.MouseButton1Click:Connect(function()
        FNFCamera.springFollow = not FNFCamera.springFollow
        cpSpring.Text = FNFCamera.springFollow and "SPRING FOLLOW: ON" or "SPRING FOLLOW: OFF"
        cpSpring.BackgroundColor3 = FNFCamera.springFollow and Color3.fromRGB(60,190,120) or Color3.fromRGB(35,35,55)
    end)

    local cpAuto = F.makeBtn(pgCam, "AUTO FRAMING: ON", UDim2.new(0,206,0,cpSetY+30),
        UDim2.new(0,190,0,26), Color3.fromRGB(60,190,120), nil, 9)
    cpAuto.MouseButton1Click:Connect(function()
        FNFCamera.autoFrame = not FNFCamera.autoFrame
        cpAuto.Text = FNFCamera.autoFrame and "AUTO FRAMING: ON" or "AUTO FRAMING: OFF"
        cpAuto.BackgroundColor3 = FNFCamera.autoFrame and Color3.fromRGB(60,190,120) or Color3.fromRGB(35,35,55)
    end)

    local cpSnap = F.makeBtn(pgCam, FNFCamera.snapHits and "SNAPPY HITS: ON" or "SNAPPY HITS: OFF",
        UDim2.new(0,8,0,cpSetY+90), UDim2.new(0,190,0,26),
        FNFCamera.snapHits and Color3.fromRGB(255,160,40) or Color3.fromRGB(35,35,55), nil, 9)
    local function syncSnap()
        cpSnap.Text = FNFCamera.snapHits and "SNAPPY HITS: ON" or "SNAPPY HITS: OFF"
        cpSnap.BackgroundColor3 = FNFCamera.snapHits and Color3.fromRGB(255,160,40) or Color3.fromRGB(35,35,55)
    end
    cpSnap.MouseButton1Click:Connect(function()
        FNFCamera.snapHits = not FNFCamera.snapHits
        syncSnap()
    end)
    syncSnapRef = syncSnap
    F.makeLabel(pgCam, "Kicks land instantly instead of easing in.",
        UDim2.new(0,206,0,cpSetY+90), UDim2.new(1,-214,0,26), Color3.fromRGB(120,120,140), Enum.TextXAlignment.Left, 9)

    local cpRows = {
        { key = "nudgeScale",  label = "HIT KICK",         min = 0,   max = 3,  fmt = "%.2f" },
        { key = "tiltScale",   label = "HIT TILT",         min = 0,   max = 3,  fmt = "%.2f" },
        { key = "punchScale",  label = "HIT ZOOM",         min = 0,   max = 4,  fmt = "%.2f" },
        { key = "returnSpeed", label = "HIT RETURN SPEED", min = 0.3, max = 4,  fmt = "%.2f" },
        { key = "settleAfter", label = "SETTLE DELAY (s)", min = 0.3, max = 5,  fmt = "%.2f" },
        { key = "springStiff", label = "FOLLOW STIFFNESS", min = 3,   max = 22, fmt = "%.1f" },
        { key = "leadTime",    label = "MOTION LEAD (s)",  min = 0,   max = 0.6,fmt = "%.2f" },
        { key = "dirBoost",    label = "DIRECTIONAL KICK", min = 1,   max = 7,  fmt = "%.2f" },
        { key = "dirHold",     label = "KICK HANG TIME",   min = 0.3, max = 3,  fmt = "%.2f" },
        { key = "beatPower",   label = "BEAT ZOOM POWER",  min = 0,   max = 45, fmt = "%.1f" },
        { key = "beatAccent",  label = "DOWNBEAT ACCENT",  min = 1,   max = 3,  fmt = "%.2f" },
        { key = "orbitSpeed",  label = "ORBIT SPEED",      min = 0,   max = 2,  fmt = "%.2f" },
        { key = "orbitAmp",    label = "ORBIT SWEEP (deg)",min = 0,   max = 90, fmt = "%.0f" },
        { key = "dutch",       label = "DUTCH TILT (deg)", min = -12, max = 12, fmt = "%.1f" },
        { key = "handheld",    label = "HANDHELD DRIFT",   min = 0,   max = 2,  fmt = "%.2f" },
        { key = "lead",        label = "LEAN TOWARD SINGER",min = 0,  max = 3,  fmt = "%.2f" },
    }
    for i, row in ipairs(cpRows) do
        local ry = cpSetY + 126 + (i-1) * 44
        F.makeLabel(pgCam, row.label, UDim2.new(0,8,0,ry), UDim2.new(0,220,0,20),
            Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
        local vlbl = F.makeLabel(pgCam, string.format(row.fmt, FNFCamera[row.key]),
            UDim2.new(0,320,0,ry), UDim2.new(0,90,0,20), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Right, 10)
        F.regText(vlbl)
        local ck, cfm = row.key, row.fmt
        F.makeSlider(pgCam, UDim2.new(0,8,0,ry+22), UDim2.new(1,-16,0,14),
            row.min, row.max, FNFCamera[row.key], function(v)
                FNFCamera[ck] = v
                vlbl.Text = string.format(cfm, v)
            end)
    end
    -- ============================================================
    -- ── BOSS BATTLE CUTSCENE ──
    -- ============================================================
    local bsY = cpSetY + 126 + #cpRows * 44 + 10
    F.makeDivider(pgCam, bsY, Color3.fromRGB(200,40,40))
    local bsTitle = F.makeLabel(pgCam, "BOSS BATTLE VIEW", UDim2.new(0,8,0,bsY+6),
        UDim2.new(1,-16,0,20), Color3.fromRGB(220,60,60), Enum.TextXAlignment.Left, 12)
    bsTitle.Font = Enum.Font.GothamBold
    F.makeLabel(pgCam, "Opponent towers over you, you shrink, camera drops to the floor looking up at them.",
        UDim2.new(0,8,0,bsY+26), UDim2.new(1,-16,0,28), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 9)
    F.makeLabel(pgCam, "Scaling is local to your client - the opponent still sees themselves at normal size.",
        UDim2.new(0,8,0,bsY+54), UDim2.new(1,-16,0,28), Color3.fromRGB(200,140,60), Enum.TextXAlignment.Left, 9)

    local bsBtn = F.makeBtn(pgCam, "ENTER BOSS VIEW", UDim2.new(0,8,0,bsY+86),
        UDim2.new(0,250,0,32), Color3.fromRGB(150,35,35), nil, 11)
    bsBtn.MouseButton1Click:Connect(function() Boss.toggle() end)

    F.makeLabel(pgCam, "KEY", UDim2.new(0,266,0,bsY+86), UDim2.new(0,30,0,32),
        Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local bsKeyBtn = F.makeBtn(pgCam, Boss.key, UDim2.new(0,298,0,bsY+86),
        UDim2.new(0,64,0,32), Color3.fromRGB(25,35,48), nil, 11)
    bsKeyBtn.MouseButton1Click:Connect(function()
        bsKeyBtn.Text = "..."; bsKeyBtn.BackgroundColor3 = Color3.fromRGB(0,200,255)
        local conn; conn = F.own(UserInputService.InputBegan:Connect(function(inp)
            if inp.KeyCode and inp.KeyCode.Name ~= "Unknown" and not inp.KeyCode.Name:match("Mouse") then
                Boss.key = inp.KeyCode.Name
                bsKeyBtn.Text = Boss.key
                bsKeyBtn.BackgroundColor3 = Color3.fromRGB(25,35,48)
                conn:Disconnect()
            end
        end))
    end)

    Boss.refreshUI = function()
        if not bsBtn or not bsBtn.Parent then return end
        bsBtn.Text = Boss.active and "EXIT BOSS VIEW" or "ENTER BOSS VIEW"
        bsBtn.BackgroundColor3 = Boss.active and Color3.fromRGB(220,60,60) or Color3.fromRGB(150,35,35)
    end
    Boss.refreshUI()

    local bsRows = {
        { key = "oppScale",    label = "OPPONENT SCALE",  min = 1,   max = 6,    fmt = "%.2f", live = true },
        { key = "playerScale", label = "YOUR SCALE",      min = 0.3, max = 1.5,  fmt = "%.2f", live = true },
        { key = "dist",        label = "CAMERA DISTANCE", min = 3,   max = 18,   fmt = "%.1f" },
        { key = "height",      label = "CAMERA HEIGHT",   min = -1,  max = 6,    fmt = "%.1f" },
        { key = "lookHeight",  label = "LOOK-UP HEIGHT",  min = 1,   max = 18,   fmt = "%.1f" },
        { key = "bars",        label = "LETTERBOX",       min = 0,   max = 0.28, fmt = "%.3f" },
    }
    for i, row in ipairs(bsRows) do
        local ry = bsY + 126 + (i-1) * 44
        F.makeLabel(pgCam, row.label, UDim2.new(0,8,0,ry), UDim2.new(0,220,0,20),
            Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
        local vlbl = F.makeLabel(pgCam, string.format(row.fmt, Boss[row.key]),
            UDim2.new(0,320,0,ry), UDim2.new(0,90,0,20), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Right, 10)
        F.regText(vlbl)
        local ck, cfm, live = row.key, row.fmt, row.live
        F.makeSlider(pgCam, UDim2.new(0,8,0,ry+22), UDim2.new(1,-16,0,14),
            row.min, row.max, Boss[row.key], function(v)
                Boss[ck] = v
                vlbl.Text = string.format(cfm, v)
                if live then Boss.restyle() end
            end)
    end
    -- ============================================================
    -- ── KEYBINDS ──
    -- ============================================================
    local kbY = bsY + 126 + #bsRows * 44 + 10
    F.makeDivider(pgCam, kbY, Color3.fromRGB(160,160,255))
    local kbTitle = F.makeLabel(pgCam, "KEYBINDS", UDim2.new(0,8,0,kbY+6),
        UDim2.new(1,-16,0,20), Color3.fromRGB(160,160,255), Enum.TextXAlignment.Left, 12)
    kbTitle.Font = Enum.Font.GothamBold
    F.makeLabel(pgCam, "Every bind below works with the panel closed. Click a key to rebind it.",
        UDim2.new(0,8,0,kbY+26), UDim2.new(1,-16,0,28), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 9)

    -- helper: a rebind button plus an X that clears the bind entirely
    local function bindBtn(x, y, w, current, onSet)
        local bw = w - 26
        local b = F.makeBtn(pgCam, current == "" and "None" or current,
            UDim2.new(0,x,0,y), UDim2.new(0,bw,0,24), Color3.fromRGB(25,35,48), nil, 10)
        b.MouseButton1Click:Connect(function()
            b.Text = "..."; b.BackgroundColor3 = Color3.fromRGB(0,200,255)
            local conn; conn = F.own(UserInputService.InputBegan:Connect(function(inp)
                if inp.KeyCode and inp.KeyCode.Name ~= "Unknown" and not inp.KeyCode.Name:match("Mouse") then
                    onSet(inp.KeyCode.Name)
                    b.Text = inp.KeyCode.Name
                    b.BackgroundColor3 = Color3.fromRGB(25,35,48)
                    Keys.refresh()
                    conn:Disconnect()
                end
            end))
        end)

        local clr = F.makeBtn(pgCam, "X", UDim2.new(0, x + bw + 2, 0, y),
            UDim2.new(0, 22, 0, 24), Color3.fromRGB(150,35,35), nil, 10)
        clr.MouseButton1Click:Connect(function()
            onSet("None")
            b.Text = "None"
            b.BackgroundColor3 = Color3.fromRGB(30,30,40)
            Keys.refresh()
        end)
        return b
    end

    -- cheat sheet toggle
    local kbBtn = F.makeBtn(pgCam, "SHOW KEYBIND LIST", UDim2.new(0,8,0,kbY+58),
        UDim2.new(0,250,0,30), Color3.fromRGB(45,45,80), nil, 10)
    kbBtn.MouseButton1Click:Connect(function() Keys.setOverlay(not Keys.overlayOn) end)
    bindBtn(258, kbY+61, 92, Keys.overlayKey, function(k) Keys.overlayKey = k end)

    Keys.refreshUI = function()
        if not kbBtn or not kbBtn.Parent then return end
        kbBtn.Text = Keys.overlayOn and "HIDE KEYBIND LIST" or "SHOW KEYBIND LIST"
        kbBtn.BackgroundColor3 = Keys.overlayOn and Color3.fromRGB(80,80,160) or Color3.fromRGB(45,45,80)
    end
    Keys.refreshUI()

    F.makeLabel(pgCam, "BEAT ZOOM", UDim2.new(0,8,0,kbY+94), UDim2.new(0,90,0,24),
        Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    bindBtn(100, kbY+94, 124, Keys.beatKey, function(k) Keys.beatKey = k end)
    F.makeLabel(pgCam, "Toggles the lens pulsing in time with your BPM.",
        UDim2.new(0,232,0,kbY+94), UDim2.new(1,-240,0,24), Color3.fromRGB(120,120,140), Enum.TextXAlignment.Left, 9)

    F.makeLabel(pgCam, "LIST OPACITY", UDim2.new(0,8,0,kbY+128), UDim2.new(0,200,0,20),
        Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local kbOpLbl = F.makeLabel(pgCam, string.format("%.2f", Keys.opacity),
        UDim2.new(0,320,0,kbY+128), UDim2.new(0,90,0,20), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Right, 10)
    F.regText(kbOpLbl)
    F.makeSlider(pgCam, UDim2.new(0,8,0,kbY+150), UDim2.new(1,-16,0,14), 0.1, 0.9, Keys.opacity, function(v)
        Keys.opacity = v
        kbOpLbl.Text = string.format("%.2f", v)
        Keys.applyOpacity()
    end)

    -- intro transition binds
    F.makeLabel(pgCam, "INTRO TRANSITIONS", UDim2.new(0,8,0,kbY+176), UDim2.new(1,-16,0,18),
        Color3.fromRGB(255,200,60), Enum.TextXAlignment.Left, 10)
    for i, e in ipairs(Keys.intro) do
        local ry = kbY + 198 + (i-1) * 30
        F.makeLabel(pgCam, e.label, UDim2.new(0,8,0,ry), UDim2.new(0,220,0,24),
            Color3.fromRGB(180,180,195), Enum.TextXAlignment.Left, 10)
        local entry = e
        bindBtn(276, ry, 124, e.key, function(k) entry.key = k end)
    end

    -- cinematic preset binds
    local kbPY = kbY + 198 + #Keys.intro * 30 + 10
    F.makeLabel(pgCam, "CINEMATIC PRESETS", UDim2.new(0,8,0,kbPY), UDim2.new(1,-16,0,18),
        Color3.fromRGB(255,200,60), Enum.TextXAlignment.Left, 10)
    for i, e in ipairs(Keys.preset) do
        local ry = kbPY + 22 + (i-1) * 30
        F.makeLabel(pgCam, e.name, UDim2.new(0,8,0,ry), UDim2.new(0,220,0,24),
            Color3.fromRGB(180,180,195), Enum.TextXAlignment.Left, 10)
        local entry = e
        bindBtn(276, ry, 124, e.key, function(k) entry.key = k end)
    end








    -- ============================================================
    -- ── RIDE LOCK ──
    -- ============================================================
    local rdY = kbPY + 22 + #Keys.preset * 30 + 20
    F.makeDivider(pgCam, rdY, Color3.fromRGB(120,220,255))
    local rdTitle = F.makeLabel(pgCam, "RIDE LOCK", UDim2.new(0,8,0,rdY+6),
        UDim2.new(1,-16,0,20), Color3.fromRGB(120,220,255), Enum.TextXAlignment.Left, 12)
    rdTitle.Font = Enum.Font.GothamBold
    F.makeLabel(pgCam, "Locks you to the object you're on and keeps you there at any speed, on your screen and on other players'. You can still walk around on it and jump — you land back on the same spot.",
        UDim2.new(0,8,0,rdY+26), UDim2.new(1,-16,0,40), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 9)

    local rdBtn = F.makeBtn(pgCam, "LOCK ON", UDim2.new(0,8,0,rdY+70),
        UDim2.new(0,250,0,30), Color3.fromRGB(35,35,55), nil, 10)
    rdBtn.MouseButton1Click:Connect(function() Ride.setEnabled(not Ride.enabled) end)

    F.makeLabel(pgCam, "KEY", UDim2.new(0,266,0,rdY+70), UDim2.new(0,30,0,30),
        Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local rdKeyBtn = F.makeBtn(pgCam, Ride.key, UDim2.new(0,298,0,rdY+70),
        UDim2.new(0,64,0,30), Color3.fromRGB(25,35,48), nil, 10)
    rdKeyBtn.MouseButton1Click:Connect(function()
        rdKeyBtn.Text = "..."; rdKeyBtn.BackgroundColor3 = Color3.fromRGB(0,200,255)
        local conn; conn = F.own(UserInputService.InputBegan:Connect(function(inp)
            if inp.KeyCode and inp.KeyCode.Name ~= "Unknown" and not inp.KeyCode.Name:match("Mouse") then
                Ride.key = inp.KeyCode.Name
                rdKeyBtn.Text = Ride.key
                rdKeyBtn.BackgroundColor3 = Color3.fromRGB(25,35,48)
                if Keys.refresh then Keys.refresh() end
                conn:Disconnect()
            end
        end))
    end)

    Ride.refreshUI = function()
        if not rdBtn or not rdBtn.Parent then return end
        rdBtn.Text = Ride.enabled and "UNLOCK" or "LOCK ON"
        rdBtn.BackgroundColor3 = Ride.enabled and Color3.fromRGB(60,160,220) or Color3.fromRGB(35,35,55)
    end
    Ride.refreshUI()

    local rdStatus = F.makeLabel(pgCam, "", UDim2.new(0,8,0,rdY+106),
        UDim2.new(1,-16,0,24), Color3.fromRGB(160,160,180), Enum.TextXAlignment.Left, 9)
    rdStatus.TextWrapped = true
    rdStatus.TextYAlignment = Enum.TextYAlignment.Top
    task.spawn(function()
        while F.alive do
            task.wait(0.25)
            if not rdStatus.Parent then break end
            if Ride.enabled and Ride.part then
                local pingTxt
                if Ride.pingSource == "AVERAGE" and Ride.pingOthers then
                    pingTxt = string.format("average ping %d ms (%d players)",
                        math.floor(Ride.pingMs + 0.5), Ride.pingCount)
                else
                    pingTxt = string.format("ping %d ms (yours only)", math.floor(Ride.pingMs + 0.5))
                end
                rdStatus.Text = string.format("locked to %s  |  %.0f studs/s, turning %.0f°/s  |  %s\n%s  |  sending you %d ms ahead (%.1f studs)",
                    Ride.part.Name:sub(1, 14), Ride.smooth, Ride.turnDeg,
                    Ride.grounded and "on it" or "jumping", pingTxt,
                    math.floor(Ride.leadTime * 1000 + 0.5), Ride.leadStuds)
                rdStatus.TextColor3 = Color3.fromRGB(120,220,255)
            else
                rdStatus.Text = "not locked"
                rdStatus.TextColor3 = Color3.fromRGB(130,130,150)
            end
        end
    end)

    local rdToggles = {
        { key = "walkWith",   on = "WALK ON IT: ON",  off = "WALK ON IT: OFF" },
        { key = "jumpWith",   on = "JUMP: ON",        off = "JUMP: OFF" },
        { key = "clampEdges", on = "STAY ON: ON",     off = "STAY ON: OFF" },
        { key = "shake",      on = "SHAKE: ON",       off = "SHAKE: OFF" },
        { key = "wind",       on = "WIND: ON",        off = "WIND: OFF" },
        { key = "speedFov",   on = "SPEED FOV: ON",   off = "SPEED FOV: OFF" },
        { key = "gLean",      on = "G-LEAN: ON",      off = "G-LEAN: OFF" },
        { key = "pingComp",   on = "PING LEAD: ON",   off = "PING LEAD: OFF" },
    }
    for i, t in ipairs(rdToggles) do
        local col = (i - 1) % 3
        local rowN = math.floor((i - 1) / 3)
        local b = F.makeBtn(pgCam, Ride[t.key] and t.on or t.off,
            UDim2.new(0, 8 + col * 132, 0, rdY + 130 + rowN * 32),
            UDim2.new(0, 126, 0, 26),
            Ride[t.key] and Color3.fromRGB(60,190,120) or Color3.fromRGB(35,35,55), nil, 9)
        local ck, on, off = t.key, t.on, t.off
        b.MouseButton1Click:Connect(function()
            Ride[ck] = not Ride[ck]
            b.Text = Ride[ck] and on or off
            b.BackgroundColor3 = Ride[ck] and Color3.fromRGB(60,190,120) or Color3.fromRGB(35,35,55)
        end)
    end

    local rdPingSrc = F.makeBtn(pgCam, "PING: " .. Ride.pingSource,
        UDim2.new(0, 8 + 2 * 132, 0, rdY + 130 + 2 * 32), UDim2.new(0,126,0,26),
        Color3.fromRGB(70,120,255), nil, 9)
    rdPingSrc.MouseButton1Click:Connect(function()
        Ride.pingSource = (Ride.pingSource == "AVERAGE") and "MINE" or "AVERAGE"
        rdPingSrc.Text = "PING: " .. Ride.pingSource
        Ride.warnedOthers, Ride.lastPingT, Ride.pingMs = false, 0, 0   -- start fresh with the new source
        F.notify(Ride.pingSource == "AVERAGE" and "Using everyone's average ping (your own is usually more accurate)"
            or "Using your ping — the number that decides the gap", "info")
    end)

    local rdRows = {
        { key = "edgeMargin",   label = "EDGE MARGIN",              min = 0,   max = 5,   fmt = "%.1f" },
        { key = "gravityScale", label = "JUMP GRAVITY",             min = 0.2, max = 3,   fmt = "%.2f" },
        { key = "pickRadius",   label = "GRAB RADIUS",              min = 4,   max = 40,  fmt = "%.0f" },
        { key = "maxSpeedAt",   label = "FULL EFFECT AT (studs/s)", min = 20,  max = 300, fmt = "%.0f" },
        { key = "minSpeed",     label = "DEADZONE (studs/s)",       min = 0,   max = 40,  fmt = "%.0f" },
        { key = "shakeScale",   label = "SHAKE AMOUNT",             min = 0,   max = 3,   fmt = "%.2f" },
        { key = "windScale",    label = "WIND AMOUNT",              min = 0,   max = 2,   fmt = "%.2f" },
        { key = "leanScale",    label = "G-LEAN AMOUNT",            min = 0,   max = 3,   fmt = "%.2f" },
        { key = "pingScale",    label = "PING LEAD STRENGTH",       min = 0,   max = 2,   fmt = "%.2f" },
        { key = "extraMs",      label = "EXTRA LEAD (ms)",          min = 0,   max = 300, fmt = "%.0f" },
    }
    for i, row in ipairs(rdRows) do
        local ry = rdY + 130 + math.ceil(#rdToggles / 3) * 32 + 6 + (i-1) * 42
        F.makeLabel(pgCam, row.label, UDim2.new(0,8,0,ry), UDim2.new(0,240,0,18),
            Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
        local vlbl = F.makeLabel(pgCam, string.format(row.fmt, Ride[row.key]),
            UDim2.new(0,316,0,ry), UDim2.new(0,80,0,18), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Right, 10)
        F.regText(vlbl)
        local ck, cfm = row.key, row.fmt
        F.makeSlider(pgCam, UDim2.new(0,8,0,ry+20), UDim2.new(1,-16,0,12),
            row.min, row.max, Ride[row.key], function(v)
                Ride[ck] = v
                vlbl.Text = string.format(cfm, v)
            end)
    end
    F.buildRideExtras(pgCam, rdY + 130 + math.ceil(#rdToggles / 3) * 32 + 6 + #rdRows * 42 + 10)
end

-- ============================================================
-- ── RIDE: WHAT OTHER PLAYERS SEE ──
-- (its own function: buildTab_Cam is close to Luau's local limit)
-- ============================================================
function F.buildRideExtras(pg, y)
    F.makeDivider(pg, y, Color3.fromRGB(120,220,255))
    local title = F.makeLabel(pg, "RIDE — WHAT OTHER PLAYERS SEE", UDim2.new(0,8,0,y+6),
        UDim2.new(1,-16,0,20), Color3.fromRGB(120,220,255), Enum.TextXAlignment.Left, 12)
    title.Font = Enum.Font.GothamBold
    local help = F.makeLabel(pg, "Others see you about one round trip late while the object keeps moving on their screen, so you're sent ahead to where it will be by then. GUESS is how that's worked out: ROUTE learns a route it repeats (trains, lifts, platforms) and knows the next bend and stop, CURVE follows bends and braking, LINE goes straight on. AUTO uses the route once it has come round and the curve until then. A free seat on it beats all of them: the game holds you there.",
        UDim2.new(0,8,0,y+26), UDim2.new(1,-16,0,78), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 9)
    help.TextWrapped = true
    help.TextYAlignment = Enum.TextYAlignment.Top

    local by = y + 108
    local order = { "AUTO", "ROUTE", "CURVE", "LINE" }
    local guessBtn = F.makeBtn(pg, "GUESS: " .. Ride.guess, UDim2.new(0,8,0,by),
        UDim2.new(0,126,0,26), Color3.fromRGB(70,120,255), nil, 9)
    guessBtn.MouseButton1Click:Connect(function()
        local i = table.find(order, Ride.guess) or 0
        Ride.guess = order[i % #order + 1]
        guessBtn.Text = "GUESS: " .. Ride.guess
        if Ride.guess == "CURVE" or Ride.guess == "LINE" then Ride.matchLag = nil end
    end)

    -- the guess button is slot 0; these fill slots 1-4, FORGET ROUTE is 5
    local toggles = {
        { key = "seatFirst", on = "SIT IF SEAT: ON", off = "SIT IF SEAT: OFF" },
        { key = "walls",     on = "WALLS: ON",       off = "WALLS: OFF" },
        { key = "noCollide", on = "NO COLLIDE: ON",  off = "NO COLLIDE: OFF" },
        { key = "showView",  on = "THEIR VIEW: ON",  off = "THEIR VIEW: OFF" },
    }
    for slot, t in ipairs(toggles) do
        local b = F.makeBtn(pg, Ride[t.key] and t.on or t.off,
            UDim2.new(0, 8 + (slot % 3) * 132, 0, by + math.floor(slot / 3) * 32),
            UDim2.new(0,126,0,26),
            Ride[t.key] and Color3.fromRGB(60,190,120) or Color3.fromRGB(35,35,55), nil, 9)
        local ck, on, off = t.key, t.on, t.off
        b.MouseButton1Click:Connect(function()
            Ride[ck] = not Ride[ck]
            b.Text = Ride[ck] and on or off
            b.BackgroundColor3 = Ride[ck] and Color3.fromRGB(60,190,120) or Color3.fromRGB(35,35,55)
            if ck == "noCollide" and Ride.enabled and not Ride.seat then
                if Ride[ck] then Ride.collideBegin() else Ride.collideEnd() end
            end
        end)
    end
    local forget = F.makeBtn(pg, "FORGET ROUTE", UDim2.new(0, 8 + 2 * 132, 0, by + 32),
        UDim2.new(0,126,0,26), Color3.fromRGB(120,60,60), nil, 9)
    forget.MouseButton1Click:Connect(function()
        Ride.routeReset()
        Ride.histPart = Ride.part
        F.notify("Route forgotten — it learns again from now", "info")
    end)

    local sy = by + 70
    F.makeLabel(pg, "ROUTE MEMORY (s) — from the next new object or FORGET", UDim2.new(0,8,0,sy),
        UDim2.new(0,300,0,18), Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local vlbl = F.makeLabel(pg, string.format("%.0f", Ride.routeSecs),
        UDim2.new(0,316,0,sy), UDim2.new(0,80,0,18), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Right, 10)
    F.regText(vlbl)
    F.makeSlider(pg, UDim2.new(0,8,0,sy+20), UDim2.new(1,-16,0,12), 20, 240, Ride.routeSecs, function(v)
        Ride.routeSecs = math.floor(v + 0.5)
        vlbl.Text = string.format("%.0f", Ride.routeSecs)
    end)

    local status = F.makeLabel(pg, "", UDim2.new(0,8,0,sy+44), UDim2.new(1,-16,0,74),
        Color3.fromRGB(160,160,180), Enum.TextXAlignment.Left, 9)
    status.TextWrapped = true
    status.TextYAlignment = Enum.TextYAlignment.Top
    task.spawn(function()
        while F.alive do
            task.wait(0.25)
            if not status.Parent then break end
            if not Ride.enabled then
                status.Text = "not locked"
                status.TextColor3 = Color3.fromRGB(130,130,150)
            elseif Ride.seat then
                status.Text = "sitting in " .. Ride.seat.Name .. " — the game holds you on it, so everyone sees you on it exactly"
                status.TextColor3 = Color3.fromRGB(110,230,150)
            elseif Ride.seatTry then
                status.Text = "sitting down on " .. Ride.seatTry.Name .. "..."
                status.TextColor3 = Color3.fromRGB(120,220,255)
            else
                local lines = { "object: " .. (Ride.kindText[Ride.kind] or "reading...") }
                if Ride.kind == "YOU" then
                    lines[2] = "guess: not needed"
                elseif not Ride.pingComp then
                    lines[2] = "guess: off (PING LEAD is off, so they see you behind it)"
                elseif Ride.matchLag then
                    lines[2] = string.format("guess: ROUTE — it repeats every %.1f s", Ride.routePeriod)
                elseif Ride.guess == "AUTO" or Ride.guess == "ROUTE" then
                    local h = Ride.hist
                    lines[2] = string.format("guess: CURVE until the route comes round (%.0f s remembered)",
                        h and h.count / 30 or 0)
                else
                    lines[2] = "guess: " .. Ride.guess
                end
                if Ride.showView then
                    lines[3] = string.format("their view: %.1f studs from where you mean to be (the glowing ghost), if ping + EXTRA LEAD match their delay",
                        Ride.viewGap)
                end
                status.Text = table.concat(lines, "\n")
                status.TextColor3 = Color3.fromRGB(120,220,255)
            end
        end
    end)
    return sy + 44 + 78
end

-- ============================================================
-- ── FLY TAB ──
-- ============================================================
function F.buildTab_Fly(pages)
    local pg = pages["✈ FLY"]
    if not pg then return end
    local C = Color3.fromRGB
    local y = 8

    local title = F.makeLabel(pg, "FLY", UDim2.new(0,8,0,y), UDim2.new(1,-16,0,20), C(120,220,255), Enum.TextXAlignment.Left, 13)
    title.Font = Enum.Font.GothamBold
    y = y + 22
    local intro = F.makeLabel(pg, "Fly around, and every pose moves you its way: LEFT, DOWN, UP or RIGHT. Everyone sees it. You still bump into walls, floors and ceilings.",
        UDim2.new(0,8,0,y), UDim2.new(1,-16,0,28), C(130,130,150), Enum.TextXAlignment.Left, 9)
    intro.TextWrapped = true
    intro.TextYAlignment = Enum.TextYAlignment.Top
    y = y + 34

    local flyBtn = F.makeBtn(pg, "", UDim2.new(0,8,0,y), UDim2.new(0,250,0,32), C(35,35,55), nil, 11)
    flyBtn.MouseButton1Click:Connect(function() Fly.toggle() end)
    F.makeLabel(pg, "KEY", UDim2.new(0,266,0,y), UDim2.new(0,30,0,32), C(160,160,160), Enum.TextXAlignment.Left, 10)
    local keyBtn = F.makeBtn(pg, Fly.key, UDim2.new(0,298,0,y), UDim2.new(0,98,0,32), C(25,35,48), nil, 10)
    keyBtn.MouseButton1Click:Connect(function()
        keyBtn.Text = "..."
        keyBtn.BackgroundColor3 = C(0,200,255)
        local conn
        conn = F.own(UserInputService.InputBegan:Connect(function(inp)
            if inp.KeyCode and inp.KeyCode.Name ~= "Unknown" and not inp.KeyCode.Name:match("Mouse") then
                Fly.key = inp.KeyCode.Name
                keyBtn.Text = Fly.key
                keyBtn.BackgroundColor3 = C(25,35,48)
                if Keys.refresh then Keys.refresh() end
                conn:Disconnect()
            end
        end))
    end)
    Fly.refreshUI = function()
        if not flyBtn.Parent then return end
        flyBtn.Text = Fly.enabled and "FLYING — LAND" or "FLY"
        flyBtn.BackgroundColor3 = Fly.enabled and C(60,160,220) or C(35,35,55)
    end
    Fly.refreshUI()
    y = y + 38

    local status = F.makeLabel(pg, "", UDim2.new(0,8,0,y), UDim2.new(1,-16,0,30), C(160,160,180), Enum.TextXAlignment.Left, 9)
    status.TextWrapped = true
    status.TextYAlignment = Enum.TextYAlignment.Top
    task.spawn(function()
        while F.alive do
            task.wait(0.25)
            if not status.Parent then break end
            if Fly.enabled then
                local how
                if Air.on then
                    how = "air combat with " .. (Air.foe and Air.foe.DisplayName or "your opponent")
                elseif Fly.layout == "SIDE" then
                    how = "side to side: facing the screen"
                elseif Fly.facing ~= "" then
                    how = "face to face with " .. Fly.facing
                else
                    how = "face to face: nobody close, facing where the camera looks"
                end
                local spd = (Fly.root and Fly.root.Parent) and Fly.root.AssemblyLinearVelocity.Magnitude or 0
                status.Text = string.format("flying  |  %.0f studs/s  |  %s", spd, how)
                status.TextColor3 = C(120,220,255)
            else
                status.Text = "not flying — WASD to fly, Space up, Ctrl down"
                status.TextColor3 = C(130,130,150)
            end
        end
    end)
    y = y + 34

    -- ---- poses move you ----
    F.makeDivider(pg, y, C(255,80,180)); y = y + 6
    local t2 = F.makeLabel(pg, "POSES MOVE YOU", UDim2.new(0,8,0,y), UDim2.new(1,-16,0,20), C(255,80,180), Enum.TextXAlignment.Left, 12)
    t2.Font = Enum.Font.GothamBold
    y = y + 24

    local faceBtn = F.makeBtn(pg, "FACE TO FACE", UDim2.new(0,8,0,y), UDim2.new(0,190,0,30), C(35,35,55), nil, 10)
    local sideBtn = F.makeBtn(pg, "SIDE TO SIDE", UDim2.new(0,206,0,y), UDim2.new(0,190,0,30), C(35,35,55), nil, 10)
    local function paintLayout()
        faceBtn.BackgroundColor3 = (Fly.layout ~= "SIDE") and C(255,80,180) or C(35,35,55)
        sideBtn.BackgroundColor3 = (Fly.layout == "SIDE") and C(255,80,180) or C(35,35,55)
    end
    paintLayout()
    faceBtn.MouseButton1Click:Connect(function() Fly.layout = "FACE"; paintLayout() end)
    sideBtn.MouseButton1Click:Connect(function() Fly.layout = "SIDE"; paintLayout() end)
    y = y + 34
    local lh = F.makeLabel(pg, "FACE TO FACE: you face your opponent (or the nearest player), and LEFT / RIGHT step you to your own left and right around them. SIDE TO SIDE: you turn to the screen like on an FNF stage, and LEFT / RIGHT go screen left and screen right. UP and DOWN go up and down in both.",
        UDim2.new(0,8,0,y), UDim2.new(1,-16,0,52), C(130,130,150), Enum.TextXAlignment.Left, 9)
    lh.TextWrapped = true
    lh.TextYAlignment = Enum.TextYAlignment.Top
    y = y + 56

    local function toggle(x, w, key, onTxt, offTxt)
        local b = F.makeBtn(pg, "", UDim2.new(0,x,0,y), UDim2.new(0,w,0,26), C(35,35,55), nil, 9)
        local function paint()
            b.Text = Fly[key] and onTxt or offTxt
            b.BackgroundColor3 = Fly[key] and C(60,190,120) or C(35,35,55)
        end
        paint()
        b.MouseButton1Click:Connect(function()
            Fly[key] = not Fly[key]
            paint()
        end)
    end
    toggle(8, 190, "poseMove", "POSE MOVES: ON", "POSE MOVES: OFF")
    toggle(206, 190, "returnHome", "RETURN AFTER: ON", "RETURN AFTER: OFF")
    y = y + 30
    toggle(8, 388, "snapCut", "SNAP WHEN A POSE CUTS IN: ON", "SNAP WHEN A POSE CUTS IN: OFF")
    y = y + 30
    local rh = F.makeLabel(pg, "RETURN AFTER on: you drift back to your spot when you let go of the note. Off: every pose moves you for good. SNAP WHEN A POSE CUTS IN: a pose pressed while the last one is still moving you (or bringing you back, or still held) puts you at its spot at once instead of gliding there. It still stops short of walls.",
        UDim2.new(0,8,0,y), UDim2.new(1,-16,0,52), C(130,130,150), Enum.TextXAlignment.Left, 9)
    rh.TextWrapped = true
    rh.TextYAlignment = Enum.TextYAlignment.Top
    y = y + 56

    local function slider(key, label, minV, maxV, fmt)
        F.makeLabel(pg, label, UDim2.new(0,8,0,y), UDim2.new(0,260,0,18), C(160,160,160), Enum.TextXAlignment.Left, 10)
        local vlbl = F.makeLabel(pg, string.format(fmt, Fly[key]), UDim2.new(0,286,0,y), UDim2.new(0,110,0,18),
            C(255,80,180), Enum.TextXAlignment.Right, 10)
        F.regText(vlbl)
        F.makeSlider(pg, UDim2.new(0,8,0,y+20), UDim2.new(1,-16,0,12), minV, maxV, Fly[key], function(val)
            Fly[key] = val
            vlbl.Text = string.format(fmt, val)
        end)
        y = y + 44
    end
    slider("poseDist",   "HOW FAR A POSE MOVES YOU (studs)", 1, 10, "%.1f")
    slider("poseTime",   "HOW LONG THE MOVE TAKES (s)",      0.06, 0.6, "%.2f")
    slider("returnTime", "HOW LONG THE WAY BACK TAKES (s)",  0.1, 1.5, "%.2f")

    -- ---- flying ----
    F.makeDivider(pg, y, C(120,220,255)); y = y + 6
    local t3 = F.makeLabel(pg, "FLYING", UDim2.new(0,8,0,y), UDim2.new(1,-16,0,20), C(120,220,255), Enum.TextXAlignment.Left, 12)
    t3.Font = Enum.Font.GothamBold
    y = y + 24
    slider("speed", "FLY SPEED (studs/s)", 2, 40, "%.0f")
    toggle(8, 190, "lookFly", "FLY WHERE YOU LOOK: ON", "FLY WHERE YOU LOOK: OFF")
    toggle(206, 190, "hover", "HOVER BOB: ON", "HOVER BOB: OFF")
    y = y + 30
    toggle(8, 190, "lean", "LEAN INTO MOVES: ON", "LEAN INTO MOVES: OFF")
    toggle(206, 190, "anims", "SWIM ANIMATION: ON", "SWIM ANIMATION: OFF")
    y = y + 30
    local fh = F.makeLabel(pg, "FLY WHERE YOU LOOK: forward goes up or down with the camera. SWIM ANIMATION uses your character's own swim (R15 has one, R6 uses its idle); your poses play over it.",
        UDim2.new(0,8,0,y), UDim2.new(1,-16,0,40), C(130,130,150), Enum.TextXAlignment.Left, 9)
    fh.TextWrapped = true
    fh.TextYAlignment = Enum.TextYAlignment.Top
    F.buildAirSection(pg, y + 46)
end

-- ============================================================
-- ── FLY TAB: AIR COMBAT ──
-- ============================================================
function F.buildAirSection(pg, y)
    local C = Color3.fromRGB
    local ORANGE = C(255, 150, 60)

    F.makeDivider(pg, y, ORANGE); y = y + 6
    local title = F.makeLabel(pg, "AIR COMBAT", UDim2.new(0,8,0,y), UDim2.new(1,-16,0,20), ORANGE, Enum.TextXAlignment.Left, 12)
    title.Font = Enum.Font.GothamBold
    y = y + 24
    local function note(str, h)
        local l = F.makeLabel(pg, str, UDim2.new(0,8,0,y), UDim2.new(1,-16,0,h), C(130,130,150), Enum.TextXAlignment.Left, 9)
        l.TextWrapped = true
        l.TextYAlignment = Enum.TextYAlignment.Top
        y = y + h + 4
        return l
    end
    note("Hand-to-hand in the air with your FNF opponent, for RP: nobody takes real damage, the health bars are only on your screen. Your notes are jabs, their notes hit you and knock you back. Hit the same arrow at the same moment and it's a CLASH: you teleport somewhere else mid-air (them too, if they run this script). Lose and you're KO'd mid-air, then you fall.", 64)

    local fightBtn = F.makeBtn(pg, "", UDim2.new(0,8,0,y), UDim2.new(0,388,0,32), C(35,35,55), nil, 11)
    fightBtn.MouseButton1Click:Connect(function() Air.toggle() end)
    y = y + 38
    local status = F.makeLabel(pg, "", UDim2.new(0,8,0,y), UDim2.new(1,-16,0,30), C(160,160,180), Enum.TextXAlignment.Left, 9)
    status.TextWrapped = true
    status.TextYAlignment = Enum.TextYAlignment.Top
    y = y + 34

    local function paintStatus()
        if Air.on then
            local st = (Air.state == "INTRO" and "get ready") or (Air.state == "KO" and "K.O.") or "fighting"
            status.Text = string.format("%s %s  |  round %d  |  you %d%%  ·  them %d%%  |  rounds won %d - %d",
                st, Air.foe and Air.foe.DisplayName or "", Air.round,
                math.floor(Air.hpMe * 100 + 0.5), math.floor(Air.hpThem * 100 + 0.5), Air.winsMe, Air.winsThem)
            status.TextColor3 = ORANGE
        elseif currentTarget then
            status.Text = "ready — your opponent is " .. currentTarget.DisplayName .. ". START FIGHT takes off too if you're not flying."
            status.TextColor3 = C(130,130,150)
        else
            status.Text = "pick your FNF opponent first, then START FIGHT"
            status.TextColor3 = C(130,130,150)
        end
    end
    task.spawn(function()
        while F.alive do
            task.wait(0.25)
            if not status.Parent then break end
            paintStatus()
        end
    end)

    -- rounds
    F.makeLabel(pg, "ROUNDS", UDim2.new(0,8,0,y), UDim2.new(0,80,0,26), C(160,160,160), Enum.TextXAlignment.Left, 10)
    local roundBtns = {}
    local function paintRounds()
        for n, b in pairs(roundBtns) do
            b.BackgroundColor3 = (Air.rounds == n) and ORANGE or C(35,35,55)
        end
    end
    for i, n in ipairs({ 1, 3, 5 }) do
        local b = F.makeBtn(pg, (n == 1) and "1 ROUND" or ("BEST OF " .. n),
            UDim2.new(0, 84 + (i - 1) * 106, 0, y), UDim2.new(0, 100, 0, 26), C(35,35,55), nil, 9)
        b.MouseButton1Click:Connect(function()
            if Air.on then
                F.notify("Change the rounds between fights", "warn")
                return
            end
            Air.rounds = n
            paintRounds()
        end)
        roundBtns[n] = b
    end
    paintRounds()
    y = y + 32

    local function toggle(x, w, key, onTxt, offTxt)
        local b = F.makeBtn(pg, "", UDim2.new(0,x,0,y), UDim2.new(0,w,0,26), C(35,35,55), nil, 9)
        local function paint()
            b.Text = Air[key] and onTxt or offTxt
            b.BackgroundColor3 = Air[key] and C(60,190,120) or C(35,35,55)
        end
        paint()
        b.MouseButton1Click:Connect(function()
            Air[key] = not Air[key]
            paint()
        end)
    end
    local function slider(key, label, minV, maxV, fmt)
        F.makeLabel(pg, label, UDim2.new(0,8,0,y), UDim2.new(0,270,0,18), C(160,160,160), Enum.TextXAlignment.Left, 10)
        local vlbl = F.makeLabel(pg, string.format(fmt, Air[key]), UDim2.new(0,286,0,y), UDim2.new(0,110,0,18),
            ORANGE, Enum.TextXAlignment.Right, 10)
        F.regText(vlbl)
        F.makeSlider(pg, UDim2.new(0,8,0,y+20), UDim2.new(1,-16,0,12), minV, maxV, Air[key], function(val)
            Air[key] = val
            vlbl.Text = string.format(fmt, val)
        end)
        y = y + 44
    end

    slider("damage",   "DAMAGE PER HIT (% of a bar)",    1, 20, "%.0f%%")
    slider("dashDist", "JAB DASH (studs at them)",       0, 8, "%.1f")
    slider("knock",    "KNOCKBACK WHEN THEY HIT (studs)", 0, 6, "%.1f")
    slider("koHold",   "KO POSE BEFORE YOU FALL (s)",    0.5, 3, "%.1f")

    toggle(8, 190, "circle", "CIRCLE EACH OTHER: ON", "CIRCLE EACH OTHER: OFF")
    toggle(206, 190, "keepClose", "KEEP CLOSE: ON", "KEEP CLOSE: OFF")
    y = y + 30
    slider("circleSpeed", "CIRCLING SPEED (degrees/s)", 2, 30, "%.0f")
    slider("maxDist",     "KEEP CLOSE: FURTHEST AWAY (studs)", 10, 60, "%.0f")

    -- clash
    local t2 = F.makeLabel(pg, "CLASH", UDim2.new(0,8,0,y), UDim2.new(1,-16,0,18), C(255,220,80), Enum.TextXAlignment.Left, 11)
    t2.Font = Enum.Font.GothamBold
    y = y + 22
    toggle(8, 388, "sameArrow", "CLASH NEEDS THE SAME ARROW: ON", "CLASH NEEDS THE SAME ARROW: OFF (any notes at once)")
    y = y + 30
    slider("clashWindow", "HOW CLOSE TOGETHER COUNTS AS AT ONCE (s)", 0.05, 0.4, "%.2f")
    slider("tpDist",      "CLASH TELEPORT, AT MOST (studs)", 4, 16, "%.0f")

    local teachBtn = F.makeBtn(pg, "TEACH THEIR ARROWS", UDim2.new(0,8,0,y), UDim2.new(0,190,0,26), C(35,35,55), nil, 9)
    teachBtn.MouseButton1Click:Connect(function() Air.startTeach() end)
    local teachLbl = F.makeLabel(pg, "", UDim2.new(0,206,0,y), UDim2.new(0,190,0,26), C(160,160,180), Enum.TextXAlignment.Left, 9)
    teachLbl.TextWrapped = true
    y = y + 30
    note("To clash on the same arrow, the script has to know which arrow each of their poses is. It knows when they use the same animations as your binds. For anything else press TEACH and have them hit LEFT, DOWN, UP, RIGHT once each, in that order. An arrow it can't tell clashes on timing alone.", 52)

    -- animations
    local t3 = F.makeLabel(pg, "ANIMATIONS", UDim2.new(0,8,0,y), UDim2.new(1,-16,0,18), C(255,80,180), Enum.TextXAlignment.Left, 11)
    t3.Font = Enum.Font.GothamBold
    y = y + 22
    local function idBox(x, w, key, label)
        F.makeLabel(pg, label, UDim2.new(0,x,0,y), UDim2.new(0,w,0,14), C(160,160,160), Enum.TextXAlignment.Left, 9)
        local box = F.makeBox(pg, UDim2.new(0,x,0,y+16), UDim2.new(0,w,0,26), "pose / default", Air[key])
        box.TextSize = 10
        box.FocusLost:Connect(function()
            Air[key] = box.Text:match("%d+") or ""
            box.Text = Air[key]
        end)
    end
    idBox(8,   91, "jabLEFT",  "LEFT JAB")
    idBox(107, 91, "jabDOWN",  "DOWN JAB")
    idBox(206, 91, "jabUP",    "UP JAB")
    idBox(305, 91, "jabRIGHT", "RIGHT JAB")
    y = y + 48
    idBox(8,   124, "hitAnim", "GETTING HIT")
    idBox(140, 124, "koAnim",  "KO POSE")
    idBox(272, 124, "winAnim", "WINNING A ROUND")
    y = y + 48
    note("Paste animation IDs. A blank jab plays that arrow's normal pose. Blank GETTING HIT and KO POSE use your character's own fall animation (arms flung up), and blank WINNING uses its cheer — those play in any game. Other IDs only play in a game if Roblox or that game's owner made them.", 52)

    Air.refreshUI = function()
        if not fightBtn.Parent then return end
        fightBtn.Text = Air.on and "STOP FIGHT" or "START FIGHT"
        fightBtn.BackgroundColor3 = Air.on and C(200,90,40) or C(35,35,55)
        local known = {}
        if Air.taughtFor and Air.taughtFor == currentTarget then
            for _, d in pairs(Air.taught) do known[d] = true end
        end
        local list = {}
        for _, d in ipairs(Air.DIRS) do
            if known[d] then table.insert(list, d) end
        end
        if Air.teach then
            teachLbl.Text = "waiting for their " .. Air.teach[1] .. "…"
            teachLbl.TextColor3 = C(255,220,80)
        elseif #list > 0 then
            teachLbl.Text = "taught: " .. table.concat(list, " ")
            teachLbl.TextColor3 = C(60,190,120)
        else
            teachLbl.Text = "not taught"
            teachLbl.TextColor3 = C(130,130,150)
        end
        paintStatus()
    end
    Air.refreshUI()
end

function F.buildTab_Maker(pages)
    local pg2 = pages["🎬 MAKER"]

    local makerTitle = F.makeLabel(pg2, "🎬 ANIMATION SEQUENCE MAKER",
        UDim2.new(0,8,0,6), UDim2.new(1,-16,0,20),
        Color3.fromRGB(255,80,180), Enum.TextXAlignment.Left, 12)
    F.regText(makerTitle)
    F.makeDivider(pg2, 28, Color3.fromRGB(0,200,255))
    F.makeLabel(pg2, "ANIM ID",   UDim2.new(0,8,0,34),   UDim2.new(0,220,0,16), Color3.fromRGB(160,160,160))
    F.makeLabel(pg2, "DELAY (s)", UDim2.new(0,232,0,34), UDim2.new(0,80,0,16),  Color3.fromRGB(160,160,160))

    local seqScroll = Instance.new("ScrollingFrame")
    seqScroll.Size = UDim2.new(1,-16,0,182); seqScroll.Position = UDim2.new(0,8,0,52)
    seqScroll.BackgroundColor3 = Color3.fromRGB(18,18,26); seqScroll.BorderSizePixel = 0
    seqScroll.ScrollBarThickness = 4; seqScroll.CanvasSize = UDim2.new(0,0,0,0)
    seqScroll.Parent = pg2; F.uiCorner(seqScroll)

    local seqLayout = Instance.new("UIListLayout")
    seqLayout.SortOrder = Enum.SortOrder.LayoutOrder; seqLayout.Padding = UDim.new(0,4)
    seqLayout.Parent = seqScroll
    local seqPad = Instance.new("UIPadding")
    seqPad.PaddingTop = UDim.new(0,4); seqPad.PaddingLeft = UDim.new(0,4); seqPad.PaddingRight = UDim.new(0,4)
    seqPad.Parent = seqScroll

    local function updateCanvas()
        seqScroll.CanvasSize = UDim2.new(0,0,0, seqLayout.AbsoluteContentSize.Y + 10)
    end
    seqLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)

    local seqStatusLbl = F.makeLabel(pg2, "● IDLE",
        UDim2.new(0,8,0,310), UDim2.new(1,-16,0,18), Color3.fromRGB(160,80,80), Enum.TextXAlignment.Left)

    local function addSeqRow(id, delay)
        local step = { id = id or "", delay = delay or 0.5 }
        table.insert(sequence, step)

        local row = Instance.new("Frame")
        row.Size = UDim2.new(1,-8,0,30); row.BackgroundColor3 = Color3.fromRGB(24,24,36)
        row.BorderSizePixel = 0; row.LayoutOrder = #sequence; row.Parent = seqScroll
        F.uiCorner(row, UDim.new(0,6))

        local idIn = F.makeBox(row, UDim2.new(0,4,0,3), UDim2.new(0,206,0,24), "Animation ID", step.id)
        idIn.FocusLost:Connect(function() step.id = idIn.Text:gsub("%D","") end)

        local dlIn = F.makeBox(row, UDim2.new(0,216,0,3), UDim2.new(0,64,0,24), "0.5", tostring(step.delay))
        dlIn.FocusLost:Connect(function() step.delay = tonumber(dlIn.Text) or 0.5 end)

        local rem = F.makeBtn(row, "✕", UDim2.new(0,286,0,3), UDim2.new(0,28,0,24), Color3.fromRGB(170,35,35), nil, 12)
        rem.MouseButton1Click:Connect(function()
            for j, s in ipairs(sequence) do if s == step then table.remove(sequence, j); break end end
            for j, r in ipairs(seqRowFrames) do if r == row then table.remove(seqRowFrames, j); break end end
            row:Destroy(); updateCanvas()
        end)

        table.insert(seqRowFrames, row); updateCanvas()
    end

    F.makeBtn(pg2, "+ ADD STEP", UDim2.new(0,8,0,240), UDim2.new(1,-16,0,26), Color3.fromRGB(35,35,55))
        .MouseButton1Click:Connect(function() addSeqRow("", 0.5) end)

    local seqPlay  = F.makeBtn(pg2, "▶ PLAY SEQUENCE", UDim2.new(0,8,0,272),   UDim2.new(0,176,0,30), Color3.fromRGB(60,190,120))
    local seqStop  = F.makeBtn(pg2, "■ STOP",          UDim2.new(0,192,0,272), UDim2.new(0,90,0,30),  Color3.fromRGB(190,50,50))
    local seqClear = F.makeBtn(pg2, "🗑 CLEAR",         UDim2.new(0,290,0,272), UDim2.new(0,106,0,30), Color3.fromRGB(70,25,70))

    seqPlay.MouseButton1Click:Connect(function()
        if #sequence == 0 then seqStatusLbl.Text = "⚠ Add steps first"; F.notify("Add a step first", "warn"); return end
        F.playSequence()
        seqStatusLbl.Text = "▶ RUNNING"; seqStatusLbl.TextColor3 = Color3.fromRGB(80,220,120)
        F.notify("Sequence started", "info")
        task.spawn(function()
            while seqPlaying do task.wait(0.1) end
            seqStatusLbl.Text = "● IDLE"; seqStatusLbl.TextColor3 = Color3.fromRGB(160,80,80)
        end)
    end)
    seqStop.MouseButton1Click:Connect(function()
        F.stopSequence(); seqStatusLbl.Text = "● IDLE"; seqStatusLbl.TextColor3 = Color3.fromRGB(160,80,80)
    end)
    seqClear.MouseButton1Click:Connect(function()
        F.stopSequence(); sequence = {}
        for _, r in ipairs(seqRowFrames) do pcall(function() r:Destroy() end) end
        seqRowFrames = {}; updateCanvas()
        seqStatusLbl.Text = "● IDLE"; seqStatusLbl.TextColor3 = Color3.fromRGB(160,80,80)
    end)

    F.makeDivider(pg2, 330, Color3.fromRGB(0,200,255))
    F.makeLabel(pg2, "🎵 SONG SECTIONS", UDim2.new(0,8,0,336), UDim2.new(1,-16,0,18), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Left, 12)
    F.makeLabel(pg2, "Each section holds 4 animation IDs. Switch sections live with [ and ] keys.",
        UDim2.new(0,8,0,354), UDim2.new(1,-16,0,16), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 9)

    local secCurrentLbl = F.makeLabel(pg2, "§ " .. (sections[currentSectionIdx] and sections[currentSectionIdx].name or "—"),
        UDim2.new(0,8,0,376), UDim2.new(1,-16,0,20), Color3.fromRGB(255,200,60), Enum.TextXAlignment.Left, 12)

    F.makeLabel(pg2, "PREV", UDim2.new(0,8,0,400), UDim2.new(0,36,0,24), Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 9)
    local secPrevKeyBtn = F.makeBtn(pg2, sectionPrevKey, UDim2.new(0,46,0,400), UDim2.new(0,70,0,24), Color3.fromRGB(25,35,48), nil, 9)
    secPrevKeyBtn.MouseButton1Click:Connect(function()
        secPrevKeyBtn.Text = "..."; secPrevKeyBtn.BackgroundColor3 = Color3.fromRGB(0,200,255)
        local conn; conn = F.own(UserInputService.InputBegan:Connect(function(inp)
            if inp.KeyCode and inp.KeyCode.Name ~= "Unknown" and not inp.KeyCode.Name:match("Mouse") then
                sectionPrevKey = inp.KeyCode.Name; secPrevKeyBtn.Text = sectionPrevKey
                secPrevKeyBtn.BackgroundColor3 = Color3.fromRGB(25,35,48); conn:Disconnect()
            end
        end))
    end)
    F.makeLabel(pg2, "NEXT", UDim2.new(0,124,0,400), UDim2.new(0,36,0,24), Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 9)
    local secNextKeyBtn = F.makeBtn(pg2, sectionNextKey, UDim2.new(0,162,0,400), UDim2.new(0,70,0,24), Color3.fromRGB(25,35,48), nil, 9)
    secNextKeyBtn.MouseButton1Click:Connect(function()
        secNextKeyBtn.Text = "..."; secNextKeyBtn.BackgroundColor3 = Color3.fromRGB(0,200,255)
        local conn; conn = F.own(UserInputService.InputBegan:Connect(function(inp)
            if inp.KeyCode and inp.KeyCode.Name ~= "Unknown" and not inp.KeyCode.Name:match("Mouse") then
                sectionNextKey = inp.KeyCode.Name; secNextKeyBtn.Text = sectionNextKey
                secNextKeyBtn.BackgroundColor3 = Color3.fromRGB(25,35,48); conn:Disconnect()
            end
        end))
    end)

    local secScroll = Instance.new("ScrollingFrame")
    secScroll.Size = UDim2.new(1,-16,0,320); secScroll.Position = UDim2.new(0,8,0,430)
    secScroll.BackgroundColor3 = Color3.fromRGB(18,18,26); secScroll.BackgroundTransparency = 0.5
    secScroll.BorderSizePixel = 0; secScroll.ScrollBarThickness = 3
    secScroll.CanvasSize = UDim2.new(0,0,0,0); secScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    secScroll.Parent = pg2; F.uiCorner(secScroll, UDim.new(0,8))
    local secLayout = Instance.new("UIListLayout")
    secLayout.Padding = UDim.new(0,6); secLayout.Parent = secScroll
    local secPad = Instance.new("UIPadding")
    secPad.PaddingTop = UDim.new(0,4); secPad.PaddingLeft = UDim.new(0,4); secPad.PaddingRight = UDim.new(0,4)
    secPad.Parent = secScroll

    local function buildSectionsUI()
        for _, c in ipairs(secScroll:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        for idx, sec in ipairs(sections) do
            local isActive = (idx == currentSectionIdx)
            local card = Instance.new("Frame")
            card.Size = UDim2.new(1,-4,0,120); card.BackgroundColor3 = isActive and Color3.fromRGB(40,25,55) or Color3.fromRGB(22,22,32)
            card.BackgroundTransparency = 0.3; card.BorderSizePixel = 0; card.LayoutOrder = idx
            card.Parent = secScroll; F.uiCorner(card, UDim.new(0,8))
            if isActive then F.uiStroke(card, Color3.fromRGB(255,200,60), 1.5) end

            local nameBox = F.makeBox(card, UDim2.new(0,4,0,4), UDim2.new(0,140,0,22), "Name", sec.name)
            nameBox.Font = Enum.Font.GothamBold; nameBox.TextSize = 11
            nameBox.FocusLost:Connect(function()
                if nameBox.Text ~= "" then sec.name = nameBox.Text end
            end)

            local loadBtn = F.makeBtn(card, "▶ LOAD", UDim2.new(0,150,0,4), UDim2.new(0,60,0,22), Color3.fromRGB(60,190,120), nil, 9)
            loadBtn.MouseButton1Click:Connect(function()
                currentSectionIdx = idx
                for _, row in ipairs(CurrentBindings) do
                    local newId = sec.ids[row.dir]
                    if newId and newId ~= "0" and newId ~= "" then
                        row.id = newId; F.destroyTrack(row.key)
                    end
                end
                F.notify("§ Loaded: " .. sec.name, "success")
                buildSectionsUI()
                secCurrentLbl.Text = "§ " .. sec.name
            end)

            local saveBtn = F.makeBtn(card, "💾 SAVE", UDim2.new(0,216,0,4), UDim2.new(0,60,0,22), Color3.fromRGB(70,120,255), nil, 9)
            saveBtn.MouseButton1Click:Connect(function()
                for _, row in ipairs(CurrentBindings) do
                    sec.ids[row.dir] = row.id
                end
                F.notify("Saved current binds to § " .. sec.name, "success")
            end)

            local delBtn = F.makeBtn(card, "✕", UDim2.new(0,282,0,4), UDim2.new(0,24,0,22), Color3.fromRGB(170,35,35), nil, 10)
            delBtn.MouseButton1Click:Connect(function()
                if #sections <= 1 then F.notify("Need at least one section", "warn"); return end
                table.remove(sections, idx)
                if currentSectionIdx > #sections then currentSectionIdx = #sections end
                buildSectionsUI()
            end)

            local dirOrder = { "LEFT", "DOWN", "UP", "RIGHT" }
            for di, dir in ipairs(dirOrder) do
                local dy = 30 + (di-1) * 22
                local col = ARROW_COLORS[dir] and ARROW_COLORS[dir].hit or Color3.fromRGB(255,255,255)
                F.makeLabel(card, dir, UDim2.new(0,6,0,dy), UDim2.new(0,42,0,20), col, Enum.TextXAlignment.Left, 9)
                local idBox = F.makeBox(card, UDim2.new(0,50,0,dy), UDim2.new(1,-58,0,20), "anim ID", sec.ids[dir] ~= "0" and sec.ids[dir] or "")
                idBox.TextSize = 9
                local capturedDir = dir
                idBox.FocusLost:Connect(function()
                    local cleaned = idBox.Text:gsub("%D","")
                    sec.ids[capturedDir] = cleaned ~= "" and cleaned or "0"
                end)
            end
        end
    end

    F.refreshSectionsUI = function()
        secCurrentLbl.Text = "§ " .. (sections[currentSectionIdx] and sections[currentSectionIdx].name or "—")
        buildSectionsUI()
    end

    local addSecBtn = F.makeBtn(pg2, "+ NEW SECTION", UDim2.new(0,8,0,756), UDim2.new(1,-16,0,28), Color3.fromRGB(35,35,55), nil, 11)
    addSecBtn.MouseButton1Click:Connect(function()
        local newIds = {}
        for _, row in ipairs(CurrentBindings) do newIds[row.dir] = row.id end
        table.insert(sections, { name = "Section " .. (#sections + 1), ids = newIds })
        buildSectionsUI()
        F.notify("Added new section", "success")
    end)

    local dupSecBtn = F.makeBtn(pg2, "📋 DUPLICATE CURRENT", UDim2.new(0,8,0,790), UDim2.new(1,-16,0,28), Color3.fromRGB(70,120,255), nil, 11)
    dupSecBtn.MouseButton1Click:Connect(function()
        local src = sections[currentSectionIdx]
        if not src then return end
        local copy = { name = src.name .. " (copy)", ids = {} }
        for dir, id in pairs(src.ids) do copy.ids[dir] = id end
        table.insert(sections, currentSectionIdx + 1, copy)
        buildSectionsUI()
        F.notify("Duplicated § " .. src.name, "success")
    end)

    buildSectionsUI()
end

function F.buildTab_Preview(pages)
    local pg3v = pages["👁 PREVIEW"]

    local pvTitle = F.makeLabel(pg3v, "👁 LIVE CHARACTER PREVIEW", UDim2.new(0,8,0,6), UDim2.new(1,-16,0,20), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Left, 12)
    F.regText(pvTitle)
    F.makeDivider(pg3v, 28, Color3.fromRGB(0,200,255))

    local viewport = Instance.new("ViewportFrame")
    viewport.Size = UDim2.new(1,-16,0,260); viewport.Position = UDim2.new(0,8,0,36)
    viewport.BackgroundColor3 = Color3.fromRGB(10,10,16)
    viewport.Ambient = Color3.fromRGB(140,140,150)
    viewport.LightColor = Color3.fromRGB(255,255,255)
    viewport.LightDirection = Vector3.new(-0.6, -1, -0.4)
    viewport.Parent = pg3v
    F.uiCorner(viewport)
    local vpStroke = F.uiStroke(viewport, Color3.fromRGB(255,80,180), 2)
    F.regStroke(vpStroke)

    previewCloneContainer = Instance.new("WorldModel")
    previewCloneContainer.Parent = viewport

    previewCam = Instance.new("Camera")
    previewCam.FieldOfView = 60
    previewCam.CFrame = CFrame.new(Vector3.new(0, 3, 6), Vector3.new(0, 3, 0))
    viewport.CurrentCamera = previewCam
    previewCam.Parent = viewport

    task.spawn(function()
        while F.alive do
            RunService.Heartbeat:Wait()
            if previewCam then
                previewAngle = previewAngle + 0.3
                local rad = math.rad(previewAngle)
                local dist = 6
                local pos = Vector3.new(math.sin(rad) * dist, 4, math.cos(rad) * dist)
                previewCam.CFrame = CFrame.new(pos, Vector3.new(0, 3, 0))
            end
        end
    end)

    F.makeLabel(pg3v, "Rotates automatically. Plays whatever anim you last triggered.",
        UDim2.new(0,8,0,300), UDim2.new(1,-16,0,18), Color3.fromRGB(140,140,160), Enum.TextXAlignment.Left, 10)

    local pvRefreshBtn = F.makeBtn(pg3v, "🔄 REFRESH CLONE", UDim2.new(0,8,0,324), UDim2.new(1,-16,0,28), Color3.fromRGB(70,120,255))
    pvRefreshBtn.MouseButton1Click:Connect(function()
        if character then F.buildPreviewClone(character); F.notify("Preview clone refreshed", "info") end
    end)

    F.makeDivider(pg3v, 362, Color3.fromRGB(255,80,180))
    local pvStat1 = F.makeLabel(pg3v, "Anim: —", UDim2.new(0,8,0,370), UDim2.new(1,-16,0,16), Color3.fromRGB(210,210,220), Enum.TextXAlignment.Left, 10)
    local pvStat2 = F.makeLabel(pg3v, "Speed: x1.00   BPM: 100   State: STOPPED", UDim2.new(0,8,0,388), UDim2.new(1,-16,0,16), Color3.fromRGB(160,160,180), Enum.TextXAlignment.Left, 10)
    local oldRefresh = F.refreshStatusUI
    F.refreshStatusUI = function()
        if oldRefresh then oldRefresh() end
        pvStat1.Text = string.format("Anim: %s (%s)", StatusState.currentAnimName, StatusState.currentAnimId ~= "" and StatusState.currentAnimId or "—")
        pvStat2.Text = string.format("Speed: x%.2f   BPM: %d   State: %s",
            StatusState.speedMult, StatusState.bpm, StatusState.playing and "PLAYING" or "STOPPED")
    end

    F.makeDivider(pg3v, 414, Color3.fromRGB(0,200,255))
    local recentsTitle = F.makeLabel(pg3v, "🕐 RECENT ANIMATIONS", UDim2.new(0,8,0,420), UDim2.new(1,-16,0,18), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Left, 11)
    F.regText(recentsTitle)
    local recentsScroll = Instance.new("ScrollingFrame")
    recentsScroll.Size = UDim2.new(1,-16,0,120); recentsScroll.Position = UDim2.new(0,8,0,442)
    recentsScroll.BackgroundColor3 = Color3.fromRGB(18,18,26); recentsScroll.BorderSizePixel = 0
    recentsScroll.ScrollBarThickness = 4; recentsScroll.CanvasSize = UDim2.new(0,0,0,0)
    recentsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    recentsScroll.Parent = pg3v; F.uiCorner(recentsScroll)
    local recentsLayout = Instance.new("UIListLayout")
    recentsLayout.Padding = UDim.new(0,4); recentsLayout.Parent = recentsScroll

    F.refreshRecentsUI = function()
        for _, c in ipairs(recentsScroll:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        for i, r in ipairs(recents) do
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1,-8,0,26); row.BackgroundColor3 = Color3.fromRGB(24,24,36)
            row.BorderSizePixel = 0; row.LayoutOrder = i; row.Parent = recentsScroll
            F.uiCorner(row, UDim.new(0,6))
            F.makeLabel(row, r.label.." — "..r.id, UDim2.new(0,8,0,0), UDim2.new(1,-90,1,0), Color3.fromRGB(200,200,215), Enum.TextXAlignment.Left, 10)
            local playBtn = F.makeBtn(row, "▶", UDim2.new(1,-40,0,2), UDim2.new(0,32,0,22), Color3.fromRGB(60,190,120), nil, 11)
            playBtn.MouseButton1Click:Connect(function()
                F.updatePreviewAnimation(r.id, r.label)
                F.notify("Previewing "..r.label, "info")
            end)
        end
    end
    F.refreshRecentsUI()
end

function F.buildTab_Favorites(pages)
    local pg4 = pages["❤ FAVES"]

    local favTitle = F.makeLabel(pg4, "❤ FAVORITE ANIMATIONS", UDim2.new(0,8,0,6), UDim2.new(1,-16,0,20), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Left, 12)
    F.regText(favTitle)
    F.makeDivider(pg4, 28, Color3.fromRGB(0,200,255))

    local favNameBox = F.makeBox(pg4, UDim2.new(0,8,0,36), UDim2.new(0,180,0,28), "Name")
    local favIdBox   = F.makeBox(pg4, UDim2.new(0,196,0,36), UDim2.new(0,138,0,28), "Anim ID")
    local favAddBtn  = F.makeBtn(pg4, "＋ SAVE", UDim2.new(0,340,0,36), UDim2.new(0,74,0,28), Color3.fromRGB(60,190,120), nil, 11)

    local favScroll = Instance.new("ScrollingFrame")
    favScroll.Size = UDim2.new(1,-16,0,300); favScroll.Position = UDim2.new(0,8,0,72)
    favScroll.BackgroundColor3 = Color3.fromRGB(18,18,26); favScroll.BorderSizePixel = 0
    favScroll.ScrollBarThickness = 4; favScroll.CanvasSize = UDim2.new(0,0,0,0)
    favScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    favScroll.Parent = pg4; F.uiCorner(favScroll)
    local favLayout = Instance.new("UIListLayout")
    favLayout.Padding = UDim.new(0,4); favLayout.Parent = favScroll
    local favPad = Instance.new("UIPadding")
    favPad.PaddingTop = UDim.new(0,4); favPad.PaddingLeft = UDim.new(0,4); favPad.PaddingRight = UDim.new(0,4)
    favPad.Parent = favScroll

    local function refreshFavUI()
        for _, c in ipairs(favScroll:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        for i, f in ipairs(favorites) do
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1,-8,0,32); row.BackgroundColor3 = Color3.fromRGB(24,24,36)
            row.BorderSizePixel = 0; row.LayoutOrder = i; row.Parent = favScroll
            F.uiCorner(row, UDim.new(0,6))
            F.makeLabel(row, f.name.." — "..f.id, UDim2.new(0,8,0,0), UDim2.new(1,-116,1,0), Color3.fromRGB(200,200,215), Enum.TextXAlignment.Left, 10)
            local playBtn = F.makeBtn(row, "▶", UDim2.new(1,-146,0,3), UDim2.new(0,34,0,26), Color3.fromRGB(0,180,230), nil, 11)
            local addPlBtn = F.makeBtn(row, "➕LIST", UDim2.new(1,-108,0,3), UDim2.new(0,58,0,26), Color3.fromRGB(70,120,255), nil, 9)
            local delBtn = F.makeBtn(row, "✕", UDim2.new(1,-42,0,3), UDim2.new(0,34,0,26), Color3.fromRGB(170,35,35), nil, 11)

            playBtn.MouseButton1Click:Connect(function()
                F.updatePreviewAnimation(f.id, f.name)
                F.pushRecent(f.id, f.name)
                F.notify("Previewing favorite: "..f.name, "info")
            end)
            addPlBtn.MouseButton1Click:Connect(function()
                table.insert(playlist, { name = f.name, id = f.id, delay = 1 })
                if F.refreshPlaylistUI then F.refreshPlaylistUI() end
                F.notify(f.name.." added to playlist", "success")
            end)
            delBtn.MouseButton1Click:Connect(function()
                table.remove(favorites, i)
                refreshFavUI()
            end)
        end
    end

    favAddBtn.MouseButton1Click:Connect(function()
        local id = favIdBox.Text:gsub("%D","")
        local nm = favNameBox.Text ~= "" and favNameBox.Text or ("Fav "..(#favorites+1))
        if id == "" then F.notify("Enter an anim ID to save", "warn"); return end
        table.insert(favorites, { name = nm, id = id })
        favNameBox.Text = ""; favIdBox.Text = ""
        refreshFavUI()
        F.notify("Saved to favorites: "..nm, "success")
    end)
    refreshFavUI()
end

function F.buildTab_Playlist(pages)
    local pg5 = pages["🎶 LIST"]

    local plTitle = F.makeLabel(pg5, "🎶 PLAYLIST MANAGER", UDim2.new(0,8,0,6), UDim2.new(1,-16,0,20), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Left, 12)
    F.regText(plTitle)
    F.makeDivider(pg5, 28, Color3.fromRGB(0,200,255))

    local plScroll = Instance.new("ScrollingFrame")
    plScroll.Size = UDim2.new(1,-16,0,260); plScroll.Position = UDim2.new(0,8,0,36)
    plScroll.BackgroundColor3 = Color3.fromRGB(18,18,26); plScroll.BorderSizePixel = 0
    plScroll.ScrollBarThickness = 4; plScroll.CanvasSize = UDim2.new(0,0,0,0)
    plScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    plScroll.Parent = pg5; F.uiCorner(plScroll)
    local plLayout = Instance.new("UIListLayout")
    plLayout.Padding = UDim.new(0,4); plLayout.Parent = plScroll
    local plPad = Instance.new("UIPadding")
    plPad.PaddingTop = UDim.new(0,4); plPad.PaddingLeft = UDim.new(0,4); plPad.PaddingRight = UDim.new(0,4)
    plPad.Parent = plScroll

    F.refreshPlaylistUI = function()
        for _, c in ipairs(plScroll:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        for i, item in ipairs(playlist) do
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1,-8,0,30)
            row.BackgroundColor3 = (i == playlistIndex and playlistPlaying) and Color3.fromRGB(50,30,60) or Color3.fromRGB(24,24,36)
            row.BorderSizePixel = 0; row.LayoutOrder = i; row.Parent = plScroll
            F.uiCorner(row, UDim.new(0,6))
            F.makeLabel(row, string.format("%d. %s — %s", i, item.name or item.id, item.id),
                UDim2.new(0,8,0,0), UDim2.new(1,-40,1,0), Color3.fromRGB(200,200,215), Enum.TextXAlignment.Left, 10)
            local rem = F.makeBtn(row, "✕", UDim2.new(1,-34,0,3), UDim2.new(0,26,0,24), Color3.fromRGB(170,35,35), nil, 11)
            rem.MouseButton1Click:Connect(function()
                table.remove(playlist, i)
                F.refreshPlaylistUI()
            end)
        end
    end
    F.refreshPlaylistUI()

    local plAddBox = F.makeBox(pg5, UDim2.new(0,8,0,300), UDim2.new(0,220,0,26), "Animation ID to add")
    local plAddBtn = F.makeBtn(pg5, "+ ADD", UDim2.new(0,236,0,300), UDim2.new(0,80,0,26), Color3.fromRGB(35,35,55))
    plAddBtn.MouseButton1Click:Connect(function()
        local id = plAddBox.Text:gsub("%D","")
        if id == "" then F.notify("Enter an anim ID", "warn"); return end
        table.insert(playlist, { name = "Track "..(#playlist+1), id = id, delay = 1 })
        plAddBox.Text = ""
        F.refreshPlaylistUI()
    end)

    local plPlay = F.makeBtn(pg5, "▶ PLAY", UDim2.new(0,8,0,332), UDim2.new(0,96,0,28), Color3.fromRGB(60,190,120), nil, 11)
    local plPrev = F.makeBtn(pg5, "⏮ PREV", UDim2.new(0,110,0,332), UDim2.new(0,86,0,28), Color3.fromRGB(70,120,255), nil, 11)
    local plNext = F.makeBtn(pg5, "NEXT ⏭", UDim2.new(0,202,0,332), UDim2.new(0,86,0,28), Color3.fromRGB(70,120,255), nil, 11)
    local plStop = F.makeBtn(pg5, "■ STOP", UDim2.new(0,294,0,332), UDim2.new(0,100,0,28), Color3.fromRGB(190,50,50), nil, 11)

    plPlay.MouseButton1Click:Connect(function()
        if #playlist == 0 then F.notify("Playlist is empty", "warn"); return end
        F.playPlaylist(); F.notify("Playlist started", "info")
    end)
    plPrev.MouseButton1Click:Connect(F.prevPlaylistTrack)
    plNext.MouseButton1Click:Connect(F.nextPlaylistTrack)
    plStop.MouseButton1Click:Connect(function() F.stopPlaylist(); F.refreshPlaylistUI() end)
end

function F.buildTab_FX(pages)
    local pgFx = pages["🎛 FX"]

    local vinylTitle = F.makeLabel(pgFx, "💿 VINYL RECORD", UDim2.new(0,8,0,6), UDim2.new(1,-16,0,20), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Left, 12)
    F.regText(vinylTitle)
    F.makeDivider(pgFx, 28, Color3.fromRGB(0,200,255))
    F.makeLabel(pgFx, "Spins faster the higher the current speed / BPM is.",
        UDim2.new(0,8,0,34), UDim2.new(1,-16,0,18), Color3.fromRGB(140,140,160), Enum.TextXAlignment.Left, 10)

    local vinylHolder = Instance.new("Frame")
    vinylHolder.Size = UDim2.new(0,120,0,120); vinylHolder.Position = UDim2.new(0,8,0,56)
    vinylHolder.BackgroundColor3 = Color3.fromRGB(8,8,10); vinylHolder.BorderSizePixel = 0
    vinylHolder.Parent = pgFx; F.uiCorner(vinylHolder, UDim.new(1,0))
    local vinylHolderStroke = F.uiStroke(vinylHolder, Color3.fromRGB(255,80,180), 2)
    F.regStroke(vinylHolderStroke)

    vinylImage = Instance.new("ImageLabel")
    vinylImage.Size = UDim2.new(1,-8,1,-8); vinylImage.Position = UDim2.new(0,4,0,4)
    vinylImage.BackgroundTransparency = 1
    vinylImage.Image = VINYL_DECAL_ID ~= "" and ("rbxassetid://"..VINYL_DECAL_ID) or ""
    vinylImage.ScaleType = Enum.ScaleType.Fit
    vinylImage.Parent = vinylHolder
    local vinylRing = Instance.new("Frame")
    vinylRing.Size = UDim2.new(1,0,1,0); vinylRing.BackgroundTransparency = 1
    vinylRing.Parent = vinylHolder
    F.uiCorner(vinylRing, UDim.new(1,0))
    F.uiStroke(vinylRing, Color3.fromRGB(60,60,65), 1)
    local vinylCenter = Instance.new("Frame")
    vinylCenter.Size = UDim2.new(0,14,0,14); vinylCenter.AnchorPoint = Vector2.new(0.5,0.5)
    vinylCenter.Position = UDim2.new(0.5,0,0.5,0); vinylCenter.BackgroundColor3 = Color3.fromRGB(255,80,180)
    vinylCenter.BorderSizePixel = 0; vinylCenter.Parent = vinylHolder
    F.uiCorner(vinylCenter, UDim.new(1,0)); F.regBg(vinylCenter)

    local vinylIdBox = F.makeBox(pgFx, UDim2.new(0,140,0,56), UDim2.new(1,-148,0,28), "Vinyl decal asset ID")
    vinylIdBox.FocusLost:Connect(function()
        local id = vinylIdBox.Text:gsub("%D","")
        VINYL_DECAL_ID = id
        vinylImage.Image = id ~= "" and ("rbxassetid://"..id) or ""
    end)
    F.makeLabel(pgFx, "Paste your record-label decal ID above — art rotates with the disc.",
        UDim2.new(0,140,0,88), UDim2.new(1,-148,0,32), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 10)

    F.makeLabel(pgFx, "BASE RPM", UDim2.new(0,140,0,124), UDim2.new(0,70,0,24), Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local vinylRpmBox = F.makeBox(pgFx, UDim2.new(0,214,0,124), UDim2.new(0,70,0,24), "33.3", tostring(vinylBaseRPM))
    vinylRpmBox.FocusLost:Connect(function()
        local n = tonumber(vinylRpmBox.Text)
        if n and n > 0 then vinylBaseRPM = n else vinylRpmBox.Text = tostring(vinylBaseRPM) end
    end)

    F.makeDivider(pgFx, 190, Color3.fromRGB(255,80,180))
    local crtTitle = F.makeLabel(pgFx, "📺 CRT MONITOR MODE", UDim2.new(0,8,0,196), UDim2.new(1,-16,0,20), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Left, 12)
    F.regText(crtTitle)
    F.makeLabel(pgFx, "Adds scanlines + a green-tinted flicker over the whole panel.",
        UDim2.new(0,8,0,218), UDim2.new(1,-16,0,18), Color3.fromRGB(140,140,160), Enum.TextXAlignment.Left, 10)

    local crtBtn = F.makeBtn(pgFx, "📴  CRT MODE OFF", UDim2.new(0,8,0,240), UDim2.new(1,-16,0,32), Color3.fromRGB(35,35,55), nil, 11)
    crtBtn.MouseButton1Click:Connect(function()
        crtEnabled = not crtEnabled
        if crtOverlay then crtOverlay.Visible = crtEnabled end
        if crtEnabled then
            crtBtn.Text = "📺  CRT MODE ON"
            crtBtn.BackgroundColor3 = THEMES[currentThemeName].accent
        else
            crtBtn.Text = "📴  CRT MODE OFF"
            crtBtn.BackgroundColor3 = Color3.fromRGB(35,35,55)
        end
        F.notify(crtEnabled and "CRT mode enabled" or "CRT mode disabled", "info")
    end)

    F.makeDivider(pgFx, 284, Color3.fromRGB(0,200,255))
    local specTitle = F.makeLabel(pgFx, "🎙 SPECTROGRAM (MIC)", UDim2.new(0,8,0,290), UDim2.new(1,-16,0,20), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Left, 12)
    F.regText(specTitle)
    local specStatusLbl = F.makeLabel(pgFx, "● not connected", UDim2.new(0,200,0,290), UDim2.new(1,-208,0,20), Color3.fromRGB(160,80,80), Enum.TextXAlignment.Right, 10)

    F.makeLabel(pgFx, "Uses Roblox's mic Audio API if this client/game supports it; otherwise the bars react to animation state instead.",
        UDim2.new(0,8,0,312), UDim2.new(1,-16,0,28), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 10)

    local specHolder = Instance.new("Frame")
    specHolder.Size = UDim2.new(1,-16,0,60); specHolder.Position = UDim2.new(0,8,0,346)
    specHolder.BackgroundColor3 = Color3.fromRGB(18,18,26); specHolder.BorderSizePixel = 0
    specHolder.Parent = pgFx; F.uiCorner(specHolder)
    local specLayout = Instance.new("UIListLayout")
    specLayout.FillDirection = Enum.FillDirection.Horizontal
    specLayout.Padding = UDim.new(0,3)
    specLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    specLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    specLayout.Parent = specHolder
    specBars = {}
    for i = 1, SPEC_BAR_COUNT do
        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(0, 6, 0.15, 0)
        bar.BackgroundColor3 = THEMES[currentThemeName].accent2
        bar.BorderSizePixel = 0
        bar.Parent = specHolder
        F.uiCorner(bar, UDim.new(0,2))
        table.insert(specBars, bar)
    end

    local micBtn = F.makeBtn(pgFx, "🎙 REQUEST MIC ACCESS", UDim2.new(0,8,0,414), UDim2.new(1,-16,0,30), Color3.fromRGB(70,120,255), nil, 11)
    micBtn.MouseButton1Click:Connect(function()
        local success = F.setupMicSpectrogram()
        if success then
            specStatusLbl.Text = "● mic connected"; specStatusLbl.TextColor3 = Color3.fromRGB(80,220,120)
            F.notify("Mic spectrogram connected", "success")
        else
            specStatusLbl.Text = "● using fallback"; specStatusLbl.TextColor3 = Color3.fromRGB(255,180,60)
            F.notify("Mic unavailable here — using animation-synced fallback", "warn")
        end
    end)

    F.makeDivider(pgFx, 456, Color3.fromRGB(255,80,180))
    local bpmDetectTitle = F.makeLabel(pgFx, "🎯 BPM DETECTOR", UDim2.new(0,8,0,462), UDim2.new(1,-16,0,20), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Left, 12)
    F.regText(bpmDetectTitle)
    F.makeLabel(pgFx, "Tap mode reads the rhythm of your Z/X/C/V presses. Idle mode reads the loaded idle clip's length.",
        UDim2.new(0,8,0,484), UDim2.new(1,-16,0,28), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 10)

    local detectedLbl = F.makeLabel(pgFx, "Detected: — BPM", UDim2.new(0,8,0,516), UDim2.new(1,-16,0,22), Color3.fromRGB(0,200,255), Enum.TextXAlignment.Left, 13)

    F.refreshBpmDetectorUI = function()
        if detectedBPM then
            detectedLbl.Text = string.format("Detected: %d BPM  (from %d taps)", detectedBPM, #bpmDetectTaps)
        end
    end

    F.makeLabel(pgFx, "BEATS/LOOP", UDim2.new(0,8,0,542), UDim2.new(0,80,0,26), Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local beatsBox = F.makeBox(pgFx, UDim2.new(0,90,0,542), UDim2.new(0,50,0,26), "4", tostring(beatsPerIdleLoop))
    beatsBox.FocusLost:Connect(function()
        local n = tonumber(beatsBox.Text)
        if n and n > 0 then beatsPerIdleLoop = n else beatsBox.Text = tostring(beatsPerIdleLoop) end
    end)

    local idleDetectBtn = F.makeBtn(pgFx, "📐 FROM IDLE LENGTH", UDim2.new(0,148,0,542), UDim2.new(0,150,0,26), Color3.fromRGB(70,120,255), nil, 10)
    idleDetectBtn.MouseButton1Click:Connect(function()
        local bpm = F.detectBpmFromIdleLength(beatsPerIdleLoop)
        if bpm then
            F.refreshBpmDetectorUI()
            F.notify("Detected "..bpm.." BPM from idle length", "success")
        else
            F.notify("Load an idle animation first", "warn")
        end
    end)

    local resetTapBtn = F.makeBtn(pgFx, "↺ RESET TAPS", UDim2.new(0,306,0,542), UDim2.new(0,116,0,26), Color3.fromRGB(170,35,35), nil, 10)
    resetTapBtn.MouseButton1Click:Connect(function()
        bpmDetectTaps = {}; detectedBPM = nil
        detectedLbl.Text = "Detected: — BPM"
        F.notify("Tap history cleared", "info")
    end)

    local applyDetectedBtn = F.makeBtn(pgFx, "✓ APPLY DETECTED BPM TO IDLE", UDim2.new(0,8,0,574), UDim2.new(1,-16,0,28), Color3.fromRGB(60,190,120), nil, 11)
    applyDetectedBtn.MouseButton1Click:Connect(function()
        if detectedBPM then
            F.setIdleBPM(detectedBPM)
            F.notify("Idle BPM set to "..detectedBPM, "success")
        else
            F.notify("No BPM detected yet — tap some keys or use idle length", "warn")
        end
    end)

    F.makeDivider(pgFx, 616, Color3.fromRGB(0,200,255))
    local musicTitle = F.makeLabel(pgFx, "🎵 MUSIC PLAYER (NO VC)", UDim2.new(0,8,0,622), UDim2.new(1,-16,0,20), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Left, 12)
    F.regText(musicTitle)
    F.makeLabel(pgFx, "Plays an uploaded audio asset for the whole server directly — no voice chat involved, so no mic compression/suppression.",
        UDim2.new(0,8,0,644), UDim2.new(1,-16,0,30), Color3.fromRGB(140,140,160), Enum.TextXAlignment.Left, 10)
    F.makeLabel(pgFx, "Needs the companion server script installed once in ServerScriptService (see notes).",
        UDim2.new(0,8,0,676), UDim2.new(1,-16,0,18), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 9)

    local musicIdBox = F.makeBox(pgFx, UDim2.new(0,8,0,698), UDim2.new(1,-16,0,28), "Audio asset ID (e.g. 1234567890)")

    local musicPlayBtn = F.makeBtn(pgFx, "▶ PLAY FOR EVERYONE", UDim2.new(0,8,0,730), UDim2.new(0,220,0,30), Color3.fromRGB(60,190,120), nil, 11)
    local musicStopBtn = F.makeBtn(pgFx, "■ STOP", UDim2.new(0,236,0,730), UDim2.new(0,160,0,30), Color3.fromRGB(190,50,50), nil, 11)

    musicStatusLbl = F.makeLabel(pgFx, "● idle", UDim2.new(0,8,0,766), UDim2.new(1,-16,0,20), Color3.fromRGB(160,80,80), Enum.TextXAlignment.Left, 11)

    musicPlayBtn.MouseButton1Click:Connect(function()
        local id = musicIdBox.Text:gsub("%D","")
        if id == "" then F.notify("Enter an audio asset ID first", "warn"); return end
        F.playMusicTrack(id)
        F.notify("Requested track "..id.." for the whole server", "info")
    end)
    musicStopBtn.MouseButton1Click:Connect(function()
        F.stopMusicTrack()
        F.notify("Stopped shared music", "info")
    end)
end

function F.buildTab_Video(pages)
    local pg = pages["🎞 VIDEO"]
    local C = Color3.fromRGB

    local title = F.makeLabel(pg, "VIDEO PLAYER", UDim2.new(0,8,0,6), UDim2.new(1,-16,0,22),
        C(255,80,180), Enum.TextXAlignment.Left, 14)
    title.Font = Enum.Font.GothamBlack
    F.regText(title)
    F.makeLabel(pg, "Plays videos from your computer. Only you can see them.",
        UDim2.new(0,8,0,28), UDim2.new(1,-16,0,16), C(130,130,150), Enum.TextXAlignment.Left, 9)

    -- ── what this executor can do ──
    local caps = F.makeLabel(pg, "", UDim2.new(0,8,0,48), UDim2.new(1,-16,0,16),
        C(160,160,180), Enum.TextXAlignment.Left, 10)
    local function refreshCaps()
        local a = Vid.api.asset and "YES" or "NO"
        local l = Vid.api.list and "YES" or "NO"
        caps.Text = "local video support: " .. a .. "   |   folder listing: " .. l
        caps.TextColor3 = Vid.api.asset and C(120,230,150) or C(255,120,90)
    end
    refreshCaps()

    -- ── the drop box ──
    F.makeDivider(pg, 70, THEMES[currentThemeName].accent)
    local dropHdr = F.makeLabel(pg, "YOUR VIDEOS", UDim2.new(0,8,0,76), UDim2.new(0,160,0,18),
        C(255,80,180), Enum.TextXAlignment.Left, 11)
    dropHdr.Font = Enum.Font.GothamBold
    F.regText(dropHdr)

    local howTo = F.makeLabel(pg,
        "Drag a .webm file into this folder in Windows Explorer, then press REFRESH:\n"
        .. "your executor's  workspace / " .. Vid.folder,
        UDim2.new(0,8,0,96), UDim2.new(1,-16,0,32), C(200,200,215), Enum.TextXAlignment.Left, 9)
    howTo.TextWrapped = true

    local refresh = F.makeBtn(pg, "REFRESH", UDim2.new(1,-100,0,74), UDim2.new(0,92,0,22), C(70,120,255), nil, 9)

    local list = Instance.new("ScrollingFrame")
    list.Size = UDim2.new(1,-16,0,130); list.Position = UDim2.new(0,8,0,132)
    list.BackgroundColor3 = C(12,11,18); list.BackgroundTransparency = 0.25
    list.BorderSizePixel = 0; list.ScrollBarThickness = 3
    list.CanvasSize = UDim2.new(0,0,0,0); list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.Parent = pg
    F.uiCorner(list, UDim.new(0,8))
    local ll = Instance.new("UIListLayout"); ll.Padding = UDim.new(0,3); ll.Parent = list
    local lp = Instance.new("UIPadding")
    lp.PaddingTop = UDim.new(0,4); lp.PaddingLeft = UDim.new(0,4); lp.PaddingRight = UDim.new(0,4)
    lp.Parent = list

    local function row(text, color, order)
        local l = F.makeLabel(list, text, UDim2.new(0,0,0,0), UDim2.new(1,-8,0,0),
            color, Enum.TextXAlignment.Left, 9)
        l.AutomaticSize = Enum.AutomaticSize.Y
        l.TextWrapped = true
        l.LayoutOrder = order
        return l
    end

    local function fill()
        for _, c in ipairs(list:GetChildren()) do
            if c:IsA("GuiObject") then c:Destroy() end
        end
        if not Vid.api.list then
            row("Your executor can't list folders. Type the file name below instead.", C(255,170,80), 1)
            return
        end
        local files = Vid.listFiles()
        if #files == 0 then
            row("Nothing here yet. Drop a .webm into the folder above and press REFRESH.", C(140,140,160), 1)
            return
        end
        for i, f in ipairs(files) do
            local playable = (f.ext == "webm")
            local b = F.makeBtn(list,
                (playable and "▶  " or "⚠  ") .. f.name .. (playable and "" or "   (convert to .webm)"),
                UDim2.new(0,0,0,0), UDim2.new(1,-8,0,26),
                playable and C(34,32,48) or C(55,35,30), nil, 10)
            b.TextXAlignment = Enum.TextXAlignment.Left
            b.LayoutOrder = i
            local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0,10); pad.Parent = b
            local path = f.path
            b.MouseButton1Click:Connect(function() Vid.play(path) end)
        end
    end
    refresh.MouseButton1Click:Connect(function()
        Vid.resolveApi(); refreshCaps(); fill()
    end)
    fill()

    -- ── manual entry: a file name, or a Roblox video ID ──
    local manual = F.makeBox(pg, UDim2.new(0,8,0,270), UDim2.new(1,-114,0,28),
        "file name (clip.webm) or a Roblox video ID", Vid.lastFile ~= "" and Vid.lastFile:match("[^/\\]+$") or "")
    local manualGo = F.makeBtn(pg, "PLAY", UDim2.new(1,-100,0,270), UDim2.new(0,92,0,28), C(60,190,120), nil, 11)
    manualGo.MouseButton1Click:Connect(function()
        local t = manual.Text:gsub("^%s+", ""):gsub("%s+$", "")
        if t == "" then return end
        if t:match("^%d+$") then
            Vid.play(t, true)                    -- a Roblox-hosted video
        else
            local path = t:find("/") and t or (Vid.folder .. "/" .. t)
            Vid.play(path)
        end
    end)

    Vid.statusLbl = F.makeLabel(pg, "pick a video", UDim2.new(0,8,0,302), UDim2.new(1,-16,0,28),
        C(160,160,180), Enum.TextXAlignment.Left, 10)
    Vid.statusLbl.TextWrapped = true

    -- ── transport ──
    local trY = 334
    local function tb(txt, x, w, col, fn)
        local b = F.makeBtn(pg, txt, UDim2.new(0,x,0,trY), UDim2.new(0,w,0,28), col, nil, 10)
        b.MouseButton1Click:Connect(fn)
        return b
    end
    tb("PLAY / PAUSE", 8, 126, C(60,190,120), Vid.togglePause)
    tb("RESTART", 140, 90, C(45,40,60), Vid.restart)
    tb("STOP", 236, 70, C(190,50,50), Vid.stop)
    local loopB
    loopB = tb(Vid.looped and "LOOP: ON" or "LOOP: OFF", 312, 84, Vid.looped and C(70,120,255) or C(45,40,60), function()
        Vid.looped = not Vid.looped
        if Vid.frame then Vid.frame.Looped = Vid.looped end
        loopB.Text = Vid.looped and "LOOP: ON" or "LOOP: OFF"
        loopB.BackgroundColor3 = Vid.looped and C(70,120,255) or C(45,40,60)
    end)
    Vid.timeLbl = F.makeLabel(pg, "", UDim2.new(0,8,0,trY+32), UDim2.new(1,-16,0,16),
        C(200,200,215), Enum.TextXAlignment.Left, 10)
    Vid.timeLbl.Font = Enum.Font.Code

    -- ── display mode ──
    local dY = trY + 56
    F.makeLabel(pg, "SHOW IT AS", UDim2.new(0,8,0,dY), UDim2.new(1,-16,0,16),
        C(160,160,160), Enum.TextXAlignment.Left, 10)
    local modes = { { "WINDOW", "Window" }, { "FULLSCREEN", "Fullscreen" }, { "BACKDROP", "Backdrop" } }
    local modeBtns = {}
    local function syncModes()
        local shown = Vid.stage.on and "BACKDROP" or Vid.display
        for k, b in pairs(modeBtns) do
            b.BackgroundColor3 = (k == shown) and C(255,80,180) or C(35,35,55)
            b.AutoButtonColor = not Vid.stage.on
        end
    end
    Vid.syncModes = syncModes
    for i, m in ipairs(modes) do
        local b = F.makeBtn(pg, m[2], UDim2.new(0, 8 + (i-1) * 132, 0, dY + 20), UDim2.new(0,126,0,26), C(35,35,55), nil, 10)
        modeBtns[m[1]] = b
        b.MouseButton1Click:Connect(function()
            if Vid.stage.on then
                F.notify("The stage keeps the video as the backdrop — turn it off to change this", "info")
                return
            end
            Vid.display = m[1]; syncModes(); Vid.applyLayout()
        end)
    end
    syncModes()
    F.makeLabel(pg, "Backdrop plays full screen behind every other panel.",
        UDim2.new(0,8,0,dY+50), UDim2.new(1,-16,0,14), C(120,120,140), Enum.TextXAlignment.Left, 9)

    local sliders = {
        { key = "volume",  label = "VOLUME",          min = 0,   max = 1,   fmt = "%.2f" },
        { key = "opacity", label = "SEE-THROUGH",     min = 0,   max = 0.9, fmt = "%.2f" },
        { key = "scale",   label = "WINDOW SIZE",     min = 0.5, max = 2.2, fmt = "%.2f" },
    }
    for i, s in ipairs(sliders) do
        local ry = dY + 72 + (i-1) * 42
        F.makeLabel(pg, s.label, UDim2.new(0,8,0,ry), UDim2.new(0,200,0,18), C(160,160,160), Enum.TextXAlignment.Left, 10)
        local v = F.makeLabel(pg, string.format(s.fmt, Vid[s.key]), UDim2.new(0,306,0,ry), UDim2.new(0,90,0,18),
            C(255,80,180), Enum.TextXAlignment.Right, 10)
        F.regText(v)
        local ck, cf = s.key, s.fmt
        F.makeSlider(pg, UDim2.new(0,8,0,ry+20), UDim2.new(1,-16,0,12), s.min, s.max, Vid[s.key], function(val)
            Vid[ck] = val
            v.Text = string.format(cf, val)
            if ck == "volume" and Vid.frame then Vid.frame.Volume = val end
            Vid.applyLayout()
        end)
    end

    -- ── video stage ──
    local sgY = dY + 72 + #sliders * 42 + 4
    F.makeDivider(pg, sgY, THEMES[currentThemeName].accent)
    local sgT = F.makeLabel(pg, "VIDEO STAGE", UDim2.new(0,8,0,sgY+6), UDim2.new(1,-16,0,18),
        C(255,80,180), Enum.TextXAlignment.Left, 11)
    sgT.Font = Enum.Font.GothamBold
    F.regText(sgT)
    local sgBody = F.makeLabel(pg,
        "Your video replaces the whole world. Only you and your opponent stay, in their normal colours. "
        .. "Set your opponent in the CAM tab.",
        UDim2.new(0,8,0,sgY+26), UDim2.new(1,-16,0,28), C(130,130,150), Enum.TextXAlignment.Left, 9)
    sgBody.TextWrapped = true
    local sgBtn = F.makeBtn(pg, "VIDEO STAGE OFF", UDim2.new(0,8,0,sgY+58), UDim2.new(1,-16,0,32), C(35,35,55), nil, 11)
    sgBtn.MouseButton1Click:Connect(function()
        if Vid.stage.on then Vid.stopStage() else Vid.startStage() end
    end)
    local sgInfo = F.makeLabel(pg, "", UDim2.new(0,8,0,sgY+92), UDim2.new(1,-16,0,16),
        C(160,160,180), Enum.TextXAlignment.Left, 9)
    Vid.refreshStageUI = function()
        if not sgBtn.Parent then return end
        sgBtn.Text = Vid.stage.on and "VIDEO STAGE ON" or "VIDEO STAGE OFF"
        sgBtn.BackgroundColor3 = Vid.stage.on and C(255,80,180) or C(35,35,55)
        if not Vid.stage.on then sgInfo.Text = ""; return end
        -- what the stage is actually drawing right now
        local function part(e, label, expected)
            if not expected then return label .. ": not set" end
            if not e then return label .. ": copy FAILED" end
            return string.format("%s: %d parts", label, #e.map)
        end
        local me, op = Vid.stage.me, Vid.stage.opp
        sgInfo.Text = part(me, "you", character ~= nil) .. "   |   "
            .. part(op, "opponent", currentTarget and currentTarget.Character ~= nil)
        local ok = me and #me.map > 0
        sgInfo.TextColor3 = ok and C(120,230,150) or C(255,120,90)
    end
    Vid.refreshStageUI()

    -- ── converting ──
    local cvY = sgY + 114
    F.makeDivider(pg, cvY, THEMES[currentThemeName].accent)
    local cvT = F.makeLabel(pg, "HAVE AN .MP4?", UDim2.new(0,8,0,cvY+6), UDim2.new(1,-16,0,18),
        C(255,170,80), Enum.TextXAlignment.Left, 11)
    cvT.Font = Enum.Font.GothamBold
    local cvBody = F.makeLabel(pg,
        "Roblox only plays .webm. Any free video converter works — pick WebM (VP9). "
        .. "Or with ffmpeg, run this and drop the result in the folder:",
        UDim2.new(0,8,0,cvY+26), UDim2.new(1,-16,0,30), C(200,200,215), Enum.TextXAlignment.Left, 9)
    cvBody.TextWrapped = true
    local cmd = F.makeBox(pg, UDim2.new(0,8,0,cvY+60), UDim2.new(1,-16,0,26), "",
        "ffmpeg -i input.mp4 -c:v libvpx-vp9 -b:v 2M -c:a libopus output.webm")
    cmd.TextSize = 9
    cmd.Font = Enum.Font.Code
    cmd.ClearTextOnFocus = false
    cmd.TextEditable = false
    F.makeLabel(pg, "Short clips at 720p or below load most reliably.",
        UDim2.new(0,8,0,cvY+90), UDim2.new(1,-16,0,14), C(120,120,140), Enum.TextXAlignment.Left, 9)

    -- ── black screen fade ──
    local boY = cvY + 116
    F.makeDivider(pg, boY, C(255,255,255))
    local boT = F.makeLabel(pg, "BLACK SCREEN FADE", UDim2.new(0,8,0,boY+6), UDim2.new(1,-16,0,18),
        C(235,235,245), Enum.TextXAlignment.Left, 11)
    boT.Font = Enum.Font.GothamBold
    F.makeLabel(pg, "Smoothly fades to black, holds a moment, then slowly fades back in.",
        UDim2.new(0,8,0,boY+26), UDim2.new(1,-16,0,14), C(130,130,150), Enum.TextXAlignment.Left, 9)

    local boTest = F.makeBtn(pg, "TRY IT", UDim2.new(0,8,0,boY+46), UDim2.new(0,250,0,28), C(20,20,24), nil, 11)
    boTest.MouseButton1Click:Connect(Vid.blackout)
    F.makeLabel(pg, "KEY", UDim2.new(0,266,0,boY+46), UDim2.new(0,30,0,28), C(160,160,160), Enum.TextXAlignment.Left, 10)
    local boKey = F.makeBtn(pg, Vid.boKey, UDim2.new(0,298,0,boY+46), UDim2.new(0,64,0,28), C(25,35,48), nil, 11)
    boKey.MouseButton1Click:Connect(function()
        boKey.Text = "..."; boKey.BackgroundColor3 = C(0,200,255)
        local conn; conn = F.own(UserInputService.InputBegan:Connect(function(inp)
            if inp.KeyCode and inp.KeyCode.Name ~= "Unknown" and not inp.KeyCode.Name:match("Mouse") then
                Vid.boKey = inp.KeyCode.Name
                boKey.Text = Vid.boKey
                boKey.BackgroundColor3 = C(25,35,48)
                if Keys.refresh then Keys.refresh() end
                conn:Disconnect()
            end
        end))
    end)

    local boRows = {
        { key = "boFadeIn",  label = "FADE TO BLACK (s)",  min = 0.05, max = 2, fmt = "%.2f" },
        { key = "boHold",    label = "STAY BLACK (s)",     min = 0,    max = 3, fmt = "%.2f" },
        { key = "boFadeOut", label = "FADE BACK IN (s)",   min = 0.2,  max = 6, fmt = "%.2f" },
    }
    for i, s in ipairs(boRows) do
        local ry = boY + 84 + (i-1) * 42
        F.makeLabel(pg, s.label, UDim2.new(0,8,0,ry), UDim2.new(0,200,0,18), C(160,160,160), Enum.TextXAlignment.Left, 10)
        local v = F.makeLabel(pg, string.format(s.fmt, Vid[s.key]), UDim2.new(0,306,0,ry), UDim2.new(0,90,0,18),
            C(255,80,180), Enum.TextXAlignment.Right, 10)
        F.regText(v)
        local ck, cf = s.key, s.fmt
        F.makeSlider(pg, UDim2.new(0,8,0,ry+20), UDim2.new(1,-16,0,12), s.min, s.max, Vid[s.key], function(val)
            Vid[ck] = val
            v.Text = string.format(cf, val)
        end)
    end
end

function F.buildTab_Result(pages)
    local pg = pages["🏆 RESULT"]
    local C = Color3.fromRGB

    local title = F.makeLabel(pg, "WIN / LOSE", UDim2.new(0,8,0,6), UDim2.new(1,-16,0,22),
        C(255,80,180), Enum.TextXAlignment.Left, 14)
    title.Font = Enum.Font.GothamBlack
    F.regText(title)
    F.makeLabel(pg, "You decide how the battle ends. Press a button or its key.",
        UDim2.new(0,8,0,28), UDim2.new(1,-16,0,16), C(130,130,150), Enum.TextXAlignment.Left, 9)

    -- two big buttons
    local winBtn = F.makeBtn(pg, "WIN", UDim2.new(0,8,0,52), UDim2.new(0.5,-12,0,70), C(210,160,30), C(20,20,25), 22)
    winBtn.Font = Enum.Font.GothamBlack
    winBtn.MouseButton1Click:Connect(Result.win)
    local loseBtn = F.makeBtn(pg, "LOSE", UDim2.new(0.5,4,0,52), UDim2.new(0.5,-12,0,70), C(190,40,50), nil, 22)
    loseBtn.Font = Enum.Font.GothamBlack
    loseBtn.MouseButton1Click:Connect(Result.lose)

    -- keybinds under each
    local function keyBtn(x, field)
        local b = F.makeBtn(pg, "KEY: " .. Result[field], UDim2.new(x == 0 and 0 or 0.5, x == 0 and 8 or 4, 0, 128),
            UDim2.new(0.5,-12,0,26), C(25,35,48), nil, 10)
        b.MouseButton1Click:Connect(function()
            b.Text = "press a key..."; b.BackgroundColor3 = C(0,200,255)
            local conn; conn = F.own(UserInputService.InputBegan:Connect(function(inp)
                if inp.KeyCode and inp.KeyCode.Name ~= "Unknown" and not inp.KeyCode.Name:match("Mouse") then
                    Result[field] = inp.KeyCode.Name
                    b.Text = "KEY: " .. Result[field]
                    b.BackgroundColor3 = C(25,35,48)
                    if Keys.refresh then Keys.refresh() end
                    conn:Disconnect()
                end
            end))
        end)
    end
    keyBtn(0, "winKey")
    keyBtn(1, "loseKey")

    local bannerBtn = F.makeBtn(pg, "", UDim2.new(0,8,0,162), UDim2.new(1,-16,0,26), C(35,35,55), nil, 10)
    local function syncBanner()
        bannerBtn.Text = Result.banner and "YOU WIN / YOU LOSE TEXT: ON" or "YOU WIN / YOU LOSE TEXT: OFF"
        bannerBtn.BackgroundColor3 = Result.banner and C(60,190,120) or C(35,35,55)
    end
    bannerBtn.MouseButton1Click:Connect(function() Result.banner = not Result.banner; syncBanner() end)
    syncBanner()

    -- ── win ──
    local wY = 200
    F.makeDivider(pg, wY, C(255,215,70))
    local wT = F.makeLabel(pg, "WIN", UDim2.new(0,8,0,wY+6), UDim2.new(1,-16,0,18), C(255,215,70), Enum.TextXAlignment.Left, 11)
    wT.Font = Enum.Font.GothamBold
    local cheerBox = F.makeBox(pg, UDim2.new(0,8,0,wY+28), UDim2.new(1,-16,0,28),
        "cheer animation ID (blank = your avatar's own cheer)", Result.cheerId)
    cheerBox.FocusLost:Connect(function()
        Result.cheerId = (cheerBox.Text:gsub("%D",""))
        cheerBox.Text = Result.cheerId
    end)
    local loopBtn = F.makeBtn(pg, "", UDim2.new(0,8,0,wY+62), UDim2.new(0,160,0,26), C(35,35,55), nil, 10)
    local function syncLoop()
        loopBtn.Text = Result.cheerLoop and "KEEP CHEERING: ON" or "KEEP CHEERING: OFF"
        loopBtn.BackgroundColor3 = Result.cheerLoop and C(210,160,30) or C(35,35,55)
    end
    loopBtn.MouseButton1Click:Connect(function() Result.cheerLoop = not Result.cheerLoop; syncLoop() end)
    syncLoop()
    F.makeLabel(pg, "Loops the cheer for the time below.", UDim2.new(0,176,0,wY+62), UDim2.new(1,-184,0,26),
        C(120,120,140), Enum.TextXAlignment.Left, 9)

    -- ── lose ──
    local lY = wY + 142
    F.makeDivider(pg, lY, C(255,70,70))
    local lT = F.makeLabel(pg, "LOSE", UDim2.new(0,8,0,lY+6), UDim2.new(1,-16,0,18), C(255,90,90), Enum.TextXAlignment.Left, 11)
    lT.Font = Enum.Font.GothamBold
    local sitBox = F.makeBox(pg, UDim2.new(0,8,0,lY+28), UDim2.new(1,-16,0,28),
        "sitting animation ID (blank = your avatar's own sit)", Result.sitId)
    sitBox.FocusLost:Connect(function()
        Result.sitId = (sitBox.Text:gsub("%D",""))
        sitBox.Text = Result.sitId
    end)

    F.makeLabel(pg, "FLING DIRECTION", UDim2.new(0,8,0,lY+62), UDim2.new(1,-16,0,16), C(160,160,160), Enum.TextXAlignment.Left, 10)
    local dirs = { { "AWAY", "Away from opponent" }, { "BACK", "Backwards" }, { "RANDOM", "Random" } }
    local dirBtns = {}
    local function syncDirs()
        for k, b in pairs(dirBtns) do
            b.BackgroundColor3 = (k == Result.direction) and C(190,40,50) or C(35,35,55)
        end
    end
    for i, d in ipairs(dirs) do
        local b = F.makeBtn(pg, d[2], UDim2.new(0, 8 + (i-1) * 132, 0, lY + 82), UDim2.new(0,126,0,26), C(35,35,55), nil, 9)
        dirBtns[d[1]] = b
        b.MouseButton1Click:Connect(function() Result.direction = d[1]; syncDirs() end)
    end
    syncDirs()

    -- speed shows studs/s and mph side by side
    local rows = {
        { key = "flingSpeed", label = "FLING SPEED",        min = 10, max = 300, speed = true },
        { key = "lift",       label = "UPWARD KICK",        min = 0,  max = 150, fmt = "%.0f studs/s" },
        { key = "spin",       label = "TUMBLE",             min = 0,  max = 40,  fmt = "%.1f" },
        { key = "getUpAfter", label = "GET UP AFTER",       min = 0.5, max = 8,  fmt = "%.1fs" },
        { key = "cheerTime",  label = "CHEER LENGTH (WIN)", min = 1,  max = 10,  fmt = "%.1fs" },
    }
    local function fmtRow(r, v)
        if r.speed then return string.format("%.0f studs/s  ≈  %.0f mph", v, Result.mph(v)) end
        return string.format(r.fmt, v)
    end
    for i, r in ipairs(rows) do
        local ry = lY + 118 + (i-1) * 42
        F.makeLabel(pg, r.label, UDim2.new(0,8,0,ry), UDim2.new(0,180,0,18), C(160,160,160), Enum.TextXAlignment.Left, 10)
        local v = F.makeLabel(pg, fmtRow(r, Result[r.key]), UDim2.new(0,186,0,ry), UDim2.new(0,210,0,18),
            C(255,80,180), Enum.TextXAlignment.Right, 10)
        F.regText(v)
        local rr = r
        F.makeSlider(pg, UDim2.new(0,8,0,ry+20), UDim2.new(1,-16,0,12), r.min, r.max, Result[r.key], function(val)
            Result[rr.key] = val
            v.Text = fmtRow(rr, val)
        end)
    end

    F.makeLabel(pg, "Your own physics, so other players see the fling. Careful near edges: it can throw you off the map.",
        UDim2.new(0,8,0,lY + 118 + #rows * 42 + 4), UDim2.new(1,-16,0,28), C(255,170,80), Enum.TextXAlignment.Left, 9).TextWrapped = true
end

function F.buildTab_Show(pages)
    local pg = pages["✨ SHOW"]
    local C = Color3.fromRGB
    local y = 6

    -- ---- small builders, so each section reads top to bottom ----
    local function header(text, color, sub)
        if y > 6 then F.makeDivider(pg, y, color); y = y + 6 end
        local t = F.makeLabel(pg, text, UDim2.new(0,8,0,y), UDim2.new(1,-16,0,20), color, Enum.TextXAlignment.Left, 13)
        t.Font = Enum.Font.GothamBlack
        y = y + 22
        if sub then
            local s = F.makeLabel(pg, sub, UDim2.new(0,8,0,y), UDim2.new(1,-16,0,28), C(130,130,150), Enum.TextXAlignment.Left, 9)
            s.TextWrapped = true
            y = y + 32
        end
    end
    local function toggle(x, w, tbl, key, onTxt, offTxt, color, after)
        local b = F.makeBtn(pg, "", UDim2.new(0,x,0,y), UDim2.new(0,w,0,26), C(35,35,55), nil, 9)
        local function sync()
            b.Text = tbl[key] and onTxt or offTxt
            b.BackgroundColor3 = tbl[key] and (color or C(60,190,120)) or C(35,35,55)
        end
        b.MouseButton1Click:Connect(function()
            tbl[key] = not tbl[key]
            sync()
            if after then after() end
        end)
        sync()
        return b
    end
    local function slider(tbl, key, label, min, max, fmt, after)
        F.makeLabel(pg, label, UDim2.new(0,8,0,y), UDim2.new(0,240,0,18), C(160,160,160), Enum.TextXAlignment.Left, 10)
        local v = F.makeLabel(pg, string.format(fmt, tbl[key]), UDim2.new(0,286,0,y), UDim2.new(0,110,0,18),
            C(255,80,180), Enum.TextXAlignment.Right, 10)
        F.regText(v)
        F.makeSlider(pg, UDim2.new(0,8,0,y+20), UDim2.new(1,-16,0,12), min, max, tbl[key], function(val)
            tbl[key] = val
            v.Text = string.format(fmt, val)
            if after then after() end
        end)
        y = y + 42
    end
    local function picker(options, get, set, color, note)
        local btns = {}
        local w = math.floor((400 - (#options - 1) * 6) / #options)
        local function sync()
            for k, b in pairs(btns) do
                local on = (k == get())
                b.BackgroundColor3 = on and color or C(35,35,55)
                b.TextColor3 = on and C(15,15,20) or C(238,238,248)
            end
            if note then note() end
        end
        for i, o in ipairs(options) do
            local val, text = o[1], o[2]
            local b = F.makeBtn(pg, text, UDim2.new(0, 8 + (i-1) * (w + 6), 0, y), UDim2.new(0, w, 0, 26), C(35,35,55), nil, 9)
            btns[val] = b
            b.MouseButton1Click:Connect(function() set(val); sync() end)
        end
        y = y + 32
        sync()
    end
    local function keyButton(x, tbl, key, label)
        F.makeLabel(pg, label, UDim2.new(0,x,0,y), UDim2.new(0,70,0,26), C(160,160,160), Enum.TextXAlignment.Left, 9)
        local b = F.makeBtn(pg, tbl[key], UDim2.new(0,x+72,0,y), UDim2.new(0,58,0,26), C(25,35,48), nil, 10)
        b.MouseButton1Click:Connect(function()
            b.Text = "..."; b.BackgroundColor3 = C(0,200,255)
            local conn; conn = F.own(UserInputService.InputBegan:Connect(function(inp)
                if inp.KeyCode and inp.KeyCode.Name ~= "Unknown" and not inp.KeyCode.Name:match("Mouse") then
                    tbl[key] = inp.KeyCode.Name
                    b.Text = tbl[key]
                    b.BackgroundColor3 = C(25,35,48)
                    if Keys.refresh then Keys.refresh() end
                    conn:Disconnect()
                end
            end))
        end)
    end
    local function palette(get, set)
        local cols = { C(0,0,0), C(255,255,255), C(255,80,180), C(0,200,255), C(255,60,90), C(255,200,60), C(120,255,150), C(150,90,255) }
        local swatches = {}
        local function sync()
            local cur = get()
            for _, s in ipairs(swatches) do
                s.stroke.Thickness = (s.color == cur) and 3 or 1
                s.stroke.Color = (s.color == cur) and C(255,220,90) or C(255,255,255)
            end
        end
        for i, col in ipairs(cols) do
            local b = Instance.new("TextButton")
            b.Position = UDim2.new(0, 8 + (i-1) * 50, 0, y)
            b.Size = UDim2.new(0, 42, 0, 26)
            b.BackgroundColor3 = col
            b.Text = ""
            b.AutoButtonColor = true
            b.BorderSizePixel = 0
            b.Parent = pg
            F.uiCorner(b, UDim.new(0, 6))
            local st = F.uiStroke(b, C(255,255,255), 1)
            table.insert(swatches, { color = col, stroke = st })
            b.MouseButton1Click:Connect(function() set(col); sync() end)
        end
        y = y + 32
        sync()
    end

    -- ============================================================
    header("CAMERA 2.0", C(255,80,180), "Extras that stack on top of whichever camera preset you're using.")

    -- beat pulses
    local bpLbl = F.makeLabel(pg, "BEAT PULSES", UDim2.new(0,8,0,y), UDim2.new(1,-16,0,16), C(235,235,245), Enum.TextXAlignment.Left, 11)
    bpLbl.Font = Enum.Font.GothamBold
    y = y + 20
    local bzBtn = F.makeBtn(pg, "", UDim2.new(0,8,0,y), UDim2.new(0,190,0,26), C(35,35,55), nil, 9)
    local function syncBz()
        bzBtn.Text = FNFCamera.beatZoom and "PULSE ON THE BEAT: ON" or "PULSE ON THE BEAT: OFF"
        bzBtn.BackgroundColor3 = FNFCamera.beatZoom and C(255,80,180) or C(35,35,55)
    end
    bzBtn.MouseButton1Click:Connect(function() FNFCamera:SetBeatZoom(not FNFCamera.beatZoom); syncBz() end)
    syncBz()
    F.makeLabel(pg, "Same as the ; key. Follows your BPM.", UDim2.new(0,206,0,y), UDim2.new(1,-214,0,26), C(120,120,140), Enum.TextXAlignment.Left, 9)
    y = y + 32
    picker({ { 1, "Every beat" }, { 2, "Every 2 beats" }, { 4, "Every 4 beats" } },
        function() return math.floor(Cam2.pulseEvery + 0.5) end,
        function(v) Cam2.pulseEvery = v end, C(255,80,180))
    slider(FNFCamera, "beatPower", "PULSE STRENGTH", 0, 40, "%.0f")
    slider(Cam2, "beatShake", "BUMP ON EACH PULSE", 0, 0.8, "%.2f studs")

    -- opponent zoom-ins
    local ozLbl = F.makeLabel(pg, "OPPONENT ZOOM-INS", UDim2.new(0,8,0,y), UDim2.new(1,-16,0,16), C(235,235,245), Enum.TextXAlignment.Left, 11)
    ozLbl.Font = Enum.Font.GothamBold
    y = y + 20
    toggle(8, 190, Cam2, "oppZoom", "ZOOM ON THEIR POSES: ON", "ZOOM ON THEIR POSES: OFF", C(255,80,180))
    F.makeLabel(pg, "The lens pushes in and turns toward them.", UDim2.new(0,206,0,y), UDim2.new(1,-214,0,26), C(120,120,140), Enum.TextXAlignment.Left, 9)
    y = y + 32
    slider(Cam2, "oppZoomPower", "ZOOM AMOUNT", 0, 25, "%.0f")
    slider(Cam2, "oppAim", "TURN TOWARD THEM", 0, 1, "%.2f")

    -- directional shake
    local dsLbl = F.makeLabel(pg, "DIRECTIONAL SHAKE", UDim2.new(0,8,0,y), UDim2.new(1,-16,0,16), C(235,235,245), Enum.TextXAlignment.Left, 11)
    dsLbl.Font = Enum.Font.GothamBold
    y = y + 20
    toggle(8, 190, Cam2, "dirShake", "SHAKE ON NOTES: ON", "SHAKE ON NOTES: OFF", C(255,80,180))
    F.makeLabel(pg, "LEFT/RIGHT shake sideways, UP/DOWN shake up and down.", UDim2.new(0,206,0,y), UDim2.new(1,-214,0,26), C(120,120,140), Enum.TextXAlignment.Left, 9).TextWrapped = true
    y = y + 32
    slider(Cam2, "dirShakePower", "SHAKE AMOUNT", 0, 1.5, "%.2f studs")

    -- health distance
    local hdLbl = F.makeLabel(pg, "DISTANCE FOLLOWS HEALTH", UDim2.new(0,8,0,y), UDim2.new(1,-16,0,16), C(235,235,245), Enum.TextXAlignment.Left, 11)
    hdLbl.Font = Enum.Font.GothamBold
    y = y + 20
    toggle(8, 190, Cam2, "healthDist", "CLOSER WHEN LOSING: ON", "CLOSER WHEN LOSING: OFF", C(255,80,180))
    F.makeLabel(pg, "Uses the health bar (B). Healthy = normal, empty = closest.", UDim2.new(0,206,0,y), UDim2.new(1,-214,0,26), C(120,120,140), Enum.TextXAlignment.Left, 9).TextWrapped = true
    y = y + 32
    slider(Cam2, "healthClosest", "HOW CLOSE AT EMPTY", 0.3, 1, "%.2fx")

    -- intro / outro shots
    local shLbl = F.makeLabel(pg, "INTRO & OUTRO SHOTS", UDim2.new(0,8,0,y), UDim2.new(1,-16,0,16), C(235,235,245), Enum.TextXAlignment.Left, 11)
    shLbl.Font = Enum.Font.GothamBold
    y = y + 20
    local introNote
    picker({ { "SWOOP", "Swoop" }, { "DOLLY", "Dolly in" }, { "RISE", "Rise up" } },
        function() return Cam2.introStyle end, function(v) Cam2.introStyle = v end, C(120,220,255),
        function() if introNote then introNote.Text = "Intro: " .. Cam2.SHOT_HELP[Cam2.introStyle] end end)
    introNote = F.makeLabel(pg, "", UDim2.new(0,8,0,y), UDim2.new(1,-16,0,16), C(120,120,140), Enum.TextXAlignment.Left, 9)
    introNote.Text = "Intro: " .. Cam2.SHOT_HELP[Cam2.introStyle]
    y = y + 20
    local outroNote
    picker({ { "PULLBACK", "Pull back" }, { "ORBIT", "Orbit" }, { "CRANE", "Crane up" } },
        function() return Cam2.outroStyle end, function(v) Cam2.outroStyle = v end, C(255,190,80),
        function() if outroNote then outroNote.Text = "Outro: " .. Cam2.SHOT_HELP[Cam2.outroStyle] end end)
    outroNote = F.makeLabel(pg, "", UDim2.new(0,8,0,y), UDim2.new(1,-16,0,16), C(120,120,140), Enum.TextXAlignment.Left, 9)
    outroNote.Text = "Outro: " .. Cam2.SHOT_HELP[Cam2.outroStyle]
    y = y + 22

    local playIn = F.makeBtn(pg, "PLAY INTRO", UDim2.new(0,8,0,y), UDim2.new(0,196,0,30), C(0,150,210), nil, 11)
    playIn.MouseButton1Click:Connect(function() Cam2.play("INTRO") end)
    local playOut = F.makeBtn(pg, "PLAY OUTRO", UDim2.new(0,210,0,y), UDim2.new(0,196,0,30), C(210,140,30), nil, 11)
    playOut.MouseButton1Click:Connect(function() Cam2.play("OUTRO") end)
    y = y + 36
    keyButton(8, Cam2, "introKey", "INTRO KEY")
    keyButton(210, Cam2, "outroKey", "OUTRO KEY")
    y = y + 32
    toggle(8, 196, Cam2, "outroOnResult", "OUTRO ON WIN/LOSE: ON", "OUTRO ON WIN/LOSE: OFF", C(255,190,80))
    toggle(210, 196, Cam2, "introOnOpponent", "INTRO ON NEW OPPONENT: ON", "INTRO ON NEW OPPONENT: OFF", C(120,220,255))
    y = y + 32
    slider(Cam2, "shotTime", "FLY TIME", 0.5, 6, "%.1fs")
    slider(Cam2, "outroHold", "OUTRO HOLDS FOR", 0, 8, "%.1fs")

    -- custom presets
    local cpLbl = F.makeLabel(pg, "MY CAMERA PRESETS", UDim2.new(0,8,0,y), UDim2.new(1,-16,0,16), C(235,235,245), Enum.TextXAlignment.Left, 11)
    cpLbl.Font = Enum.Font.GothamBold
    y = y + 20
    F.makeLabel(pg, "Saves your whole camera setup — distance, angles, hits, and everything on this tab — under a name.",
        UDim2.new(0,8,0,y), UDim2.new(1,-16,0,28), C(130,130,150), Enum.TextXAlignment.Left, 9).TextWrapped = true
    y = y + 30
    local nameBox = F.makeBox(pg, UDim2.new(0,8,0,y), UDim2.new(1,-114,0,28), "preset name", "")
    local saveBtn = F.makeBtn(pg, "SAVE", UDim2.new(1,-100,0,y), UDim2.new(0,92,0,28), C(60,190,120), nil, 11)
    y = y + 34
    local list = Instance.new("ScrollingFrame")
    list.Position = UDim2.new(0,8,0,y); list.Size = UDim2.new(1,-16,0,120)
    list.BackgroundColor3 = C(12,11,18); list.BackgroundTransparency = 0.25
    list.BorderSizePixel = 0; list.ScrollBarThickness = 3
    list.CanvasSize = UDim2.new(0,0,0,0); list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.Parent = pg
    F.uiCorner(list, UDim.new(0,8))
    local ll = Instance.new("UIListLayout"); ll.Padding = UDim.new(0,3); ll.Parent = list
    local lp = Instance.new("UIPadding"); lp.PaddingTop = UDim.new(0,4); lp.PaddingLeft = UDim.new(0,4); lp.PaddingRight = UDim.new(0,4); lp.Parent = list
    y = y + 126

    local function fillPresets()
        for _, c in ipairs(list:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        if #Cam2.presets == 0 then
            local e = F.makeLabel(list, "No saved presets yet.", UDim2.new(0,0,0,0), UDim2.new(1,-8,0,24),
                C(130,130,150), Enum.TextXAlignment.Center, 9)
            return
        end
        for i, p in ipairs(Cam2.presets) do
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1,-8,0,28); row.BackgroundColor3 = C(28,26,38); row.BorderSizePixel = 0
            row.LayoutOrder = i; row.Parent = list
            F.uiCorner(row, UDim.new(0,6))
            F.makeLabel(row, p.name, UDim2.new(0,10,0,0), UDim2.new(1,-150,1,0), C(235,235,245), Enum.TextXAlignment.Left, 10)
            local load = F.makeBtn(row, "USE", UDim2.new(1,-136,0,3), UDim2.new(0,64,0,22), C(70,120,255), nil, 9)
            local del = F.makeBtn(row, "DELETE", UDim2.new(1,-68,0,3), UDim2.new(0,64,0,22), C(170,35,35), nil, 9)
            local idx, data, name = i, p.data, p.name
            load.MouseButton1Click:Connect(function()
                Cam2.applyPreset(data)
                F.notify("Camera preset: " .. name, "success")
            end)
            del.MouseButton1Click:Connect(function()
                table.remove(Cam2.presets, idx)
                fillPresets()
            end)
        end
    end
    saveBtn.MouseButton1Click:Connect(function()
        local name = Cam2.savePreset(nameBox.Text)
        nameBox.Text = ""
        fillPresets()
        F.notify("Saved camera preset: " .. name, "success")
    end)
    fillPresets()

    -- ============================================================
    header("CUTSCENE MODE", C(255,255,255),
        "Hides the gameplay UI so the camera and your animations play like a music video. Your keys still work.")
    local csBtn = F.makeBtn(pg, "", UDim2.new(0,8,0,y), UDim2.new(1,-16,0,32), C(35,35,55), nil, 12)
    Cutscene.refreshUI = function()
        if not csBtn.Parent then return end
        csBtn.Text = Cutscene.active and "CUTSCENE ON" or "START CUTSCENE"
        csBtn.BackgroundColor3 = Cutscene.active and C(255,80,180) or C(35,35,55)
    end
    csBtn.MouseButton1Click:Connect(Cutscene.toggle)
    Cutscene.refreshUI()
    y = y + 38
    keyButton(8, Cutscene, "key", "KEY")
    F.makeLabel(pg, "On mobile, tap the top-right corner to exit.", UDim2.new(0,146,0,y), UDim2.new(1,-154,0,26), C(120,120,140), Enum.TextXAlignment.Left, 9)
    y = y + 32
    toggle(8, 196, Cutscene, "hideRoblox", "HIDE ROBLOX UI: ON", "HIDE ROBLOX UI: OFF")
    toggle(210, 196, Cutscene, "bars", "BLACK BARS: ON", "BLACK BARS: OFF")
    y = y + 32

    -- ============================================================
    header("SILHOUETTE+", C(120,220,255), "Upgrades for silhouette mode (H), plus a spotlight that works any time.")
    toggle(8, 196, SilFX, "outline", "OUTLINE: ON", "OUTLINE: OFF", C(120,220,255))
    toggle(210, 196, SilFX, "splitColors", "DIFFERENT COLOURS: ON", "DIFFERENT COLOURS: OFF", C(120,220,255))
    y = y + 32
    F.makeLabel(pg, "OUTLINE COLOUR", UDim2.new(0,8,0,y), UDim2.new(1,-16,0,16), C(160,160,160), Enum.TextXAlignment.Left, 10)
    y = y + 18
    palette(function() return SilFX.outlineColor end, function(c) SilFX.outlineColor = c end)
    F.makeLabel(pg, "YOUR COLOUR (with different colours on)", UDim2.new(0,8,0,y), UDim2.new(1,-16,0,16), C(160,160,160), Enum.TextXAlignment.Left, 10)
    y = y + 18
    palette(function() return SilFX.playerColor end, function(c) SilFX.playerColor = c end)
    F.makeLabel(pg, "OPPONENT'S COLOUR", UDim2.new(0,8,0,y), UDim2.new(1,-16,0,16), C(160,160,160), Enum.TextXAlignment.Left, 10)
    y = y + 18
    palette(function() return SilFX.oppColor end, function(c) SilFX.oppColor = c end)
    toggle(8, 196, SilFX, "spotlight", "SPOTLIGHT: ON", "SPOTLIGHT: OFF", C(255,220,90))
    F.makeLabel(pg, "Darkens everything but you two.", UDim2.new(0,210,0,y), UDim2.new(1,-218,0,26), C(120,120,140), Enum.TextXAlignment.Left, 9)
    y = y + 32
    slider(SilFX, "spotDim", "SPOTLIGHT DARKNESS", 0.2, 0.97, "%.2f")

    -- ============================================================
    header("CHARACTER PORTRAITS", C(120,255,150), "Your avatar and your opponent's, on the health bar (B). A custom icon ID in the CAM tab still wins.")
    toggle(8, 196, Health, "portraits", "PORTRAITS: ON", "PORTRAITS: OFF", C(120,255,150), function() Health.refreshPortraits() end)
    y = y + 32
    picker({ { "BESIDE", "Beside the bar" }, { "ON", "On the bar (slides)" } },
        function() return Health.portraitSpot end, function(v) Health.portraitSpot = v end, C(120,255,150))
end

-- ============================================================
--  COPY TAB — copy a player's moves, or take their animations
-- ============================================================
function F.buildTab_Copy(pages)
    local pg = pages["👯 COPY"]
    local C = Color3.fromRGB
    local y = 6

    local title = F.makeLabel(pg, "👯 COPY A PLAYER", UDim2.new(0,8,0,y), UDim2.new(1,-16,0,22),
        C(255,80,180), Enum.TextXAlignment.Left, 14)
    title.Font = Enum.Font.GothamBlack
    F.regText(title)
    y = y + 24
    local intro = F.makeLabel(pg, "Pick a player. COPY MOVES plays what they're playing on your character, on the same frame, so everyone sees you copy them. Or put any animation they play into one of your directions below.",
        UDim2.new(0,8,0,y), UDim2.new(1,-16,0,40), C(130,130,150), Enum.TextXAlignment.Left, 9)
    intro.TextWrapped = true
    intro.TextYAlignment = Enum.TextYAlignment.Top
    y = y + 44

    -- ---- pick a player ----
    local search = F.makeBox(pg, UDim2.new(0,8,0,y), UDim2.new(1,-118,0,28), "search players (name or display name)")
    local clearBtn = F.makeBtn(pg, "CLEAR", UDim2.new(1,-104,0,y), UDim2.new(0,96,0,28), C(170,35,35), nil, 10)
    y = y + 34

    local plist = Instance.new("ScrollingFrame")
    plist.Size = UDim2.new(1,-16,0,118); plist.Position = UDim2.new(0,8,0,y)
    plist.BackgroundColor3 = C(18,18,26); plist.BackgroundTransparency = 0.2
    plist.BorderSizePixel = 0; plist.ScrollBarThickness = 3
    plist.CanvasSize = UDim2.new(0,0,0,0); plist.AutomaticCanvasSize = Enum.AutomaticSize.Y
    plist.Parent = pg
    F.uiCorner(plist)
    local playLay = Instance.new("UIListLayout")
    playLay.Padding = UDim.new(0,3); playLay.SortOrder = Enum.SortOrder.LayoutOrder; playLay.Parent = plist
    local playPad = Instance.new("UIPadding")
    playPad.PaddingTop = UDim.new(0,4); playPad.PaddingLeft = UDim.new(0,4); playPad.PaddingRight = UDim.new(0,4)
    playPad.Parent = plist
    y = y + 124

    local selLbl = F.makeLabel(pg, "", UDim2.new(0,8,0,y), UDim2.new(1,-16,0,32), C(160,160,180), Enum.TextXAlignment.Left, 10)
    selLbl.TextWrapped = true
    selLbl.TextYAlignment = Enum.TextYAlignment.Top
    y = y + 36

    local function paint(b, on, onTxt, offTxt, color)
        b.Text = on and onTxt or offTxt
        b.BackgroundColor3 = on and (color or C(60,190,120)) or C(35,35,55)
    end
    local copyBtn = F.makeBtn(pg, "", UDim2.new(0,8,0,y), UDim2.new(0,126,0,28), C(35,35,55), nil, 10)
    local walkBtn = F.makeBtn(pg, "", UDim2.new(0,140,0,y), UDim2.new(0,126,0,28), C(35,35,55), nil, 9)
    local syncBtn = F.makeBtn(pg, "", UDim2.new(0,272,0,y), UDim2.new(0,124,0,28), C(35,35,55), nil, 9)
    copyBtn.MouseButton1Click:Connect(function() Copy.setOn(not Copy.on) end)
    walkBtn.MouseButton1Click:Connect(function()
        Copy.walkToo = not Copy.walkToo
        if Copy.on then Copy.remirror() end
        Copy.redraw()
    end)
    syncBtn.MouseButton1Click:Connect(function()
        Copy.sync = not Copy.sync
        Copy.redraw()
    end)
    y = y + 34
    local moveHelp = F.makeLabel(pg, "WALK TOO also copies their walk, run, idle and jump (otherwise you keep your own). SAME FRAME keeps your copy exactly in step with theirs.",
        UDim2.new(0,8,0,y), UDim2.new(1,-16,0,26), C(130,130,150), Enum.TextXAlignment.Left, 9)
    moveHelp.TextWrapped = true
    y = y + 30

    F.makeLabel(pg, "COPY SPEED (against theirs)", UDim2.new(0,8,0,y), UDim2.new(0,260,0,18), C(160,160,160), Enum.TextXAlignment.Left, 10)
    local spdLbl = F.makeLabel(pg, string.format("x%.2f", Copy.speed), UDim2.new(0,286,0,y), UDim2.new(0,110,0,18),
        C(255,80,180), Enum.TextXAlignment.Right, 10)
    F.regText(spdLbl)
    F.makeSlider(pg, UDim2.new(0,8,0,y+20), UDim2.new(1,-16,0,12), 0.25, 2, Copy.speed, function(v)
        Copy.speed = v
        spdLbl.Text = string.format("x%.2f", v)
    end)
    y = y + 44

    -- ---- their animations into your directions ----
    F.makeDivider(pg, y, C(120,220,255)); y = y + 6
    local t2 = F.makeLabel(pg, "THEIR ANIMATIONS → YOUR DIRECTIONS", UDim2.new(0,8,0,y), UDim2.new(1,-16,0,20),
        C(120,220,255), Enum.TextXAlignment.Left, 12)
    t2.Font = Enum.Font.GothamBold
    y = y + 22
    local h2 = F.makeLabel(pg, "Everything they play shows up here (newest on top). Press ◀ ▼ ▲ ▶ to make that note play it, or ▷ to try it on yourself. FILL puts their next four different poses into LEFT, DOWN, UP, RIGHT.",
        UDim2.new(0,8,0,y), UDim2.new(1,-16,0,40), C(130,130,150), Enum.TextXAlignment.Left, 9)
    h2.TextWrapped = true
    h2.TextYAlignment = Enum.TextYAlignment.Top
    y = y + 44

    local intoBtn = F.makeBtn(pg, "", UDim2.new(0,8,0,y), UDim2.new(0,126,0,26), C(70,120,255), nil, 9)
    intoBtn.MouseButton1Click:Connect(function()
        Copy.into = (Copy.into == "BINDS") and "CUTTER" or "BINDS"
        if Copy.into == "CUTTER" and not cutterEnabled then
            F.notify("The cutter is OFF — turn it on in the CUTTER tab so your notes play these", "warn")
        end
        Copy.redraw()
    end)
    local fillBtn = F.makeBtn(pg, "", UDim2.new(0,140,0,y), UDim2.new(0,126,0,26), C(35,35,55), nil, 9)
    fillBtn.MouseButton1Click:Connect(function()
        if Copy.fill then
            Copy.fill = nil
        else
            if not Copy.target then F.notify("Pick a player first", "warn"); return end
            Copy.fill, Copy.fillUsed = { "LEFT", "DOWN", "UP", "RIGHT" }, {}
            F.notify("Their next four different poses go into LEFT, DOWN, UP, RIGHT", "info")
        end
        Copy.redraw()
    end)
    local wipeBtn = F.makeBtn(pg, "CLEAR LIST", UDim2.new(0,272,0,y), UDim2.new(0,124,0,26), C(120,40,40), nil, 9)
    wipeBtn.MouseButton1Click:Connect(function()
        Copy.seen = {}
        Copy.redraw()
    end)
    y = y + 32

    local slist = Instance.new("ScrollingFrame")
    slist.Size = UDim2.new(1,-16,0,300); slist.Position = UDim2.new(0,8,0,y)
    slist.BackgroundColor3 = C(18,18,26); slist.BackgroundTransparency = 0.2
    slist.BorderSizePixel = 0; slist.ScrollBarThickness = 3
    slist.CanvasSize = UDim2.new(0,0,0,0); slist.AutomaticCanvasSize = Enum.AutomaticSize.Y
    slist.Parent = pg
    F.uiCorner(slist)
    local seenLay = Instance.new("UIListLayout")
    seenLay.Padding = UDim.new(0,4); seenLay.SortOrder = Enum.SortOrder.LayoutOrder; seenLay.Parent = slist
    local seenPad = Instance.new("UIPadding")
    seenPad.PaddingTop = UDim.new(0,4); seenPad.PaddingLeft = UDim.new(0,4); seenPad.PaddingRight = UDim.new(0,4)
    seenPad.Parent = slist
    y = y + 306

    -- ---- the player list ----
    local function fillPlayers()
        for _, c in ipairs(plist:GetChildren()) do
            if c:IsA("GuiObject") then c:Destroy() end
        end
        local q = (search.Text or ""):lower()
        local myRoot = character and character:FindFirstChild("HumanoidRootPart")
        local rows = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and (q == "" or p.Name:lower():find(q, 1, true)
                or p.DisplayName:lower():find(q, 1, true)) then
                local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                local dist = (r and myRoot) and (r.Position - myRoot.Position).Magnitude or math.huge
                table.insert(rows, { plr = p, dist = dist })
            end
        end
        table.sort(rows, function(a, b) return a.dist < b.dist end)
        if #rows == 0 then
            F.makeLabel(plist, (q == "") and "Nobody else here" or "No player matches", UDim2.new(0,0,0,0),
                UDim2.new(1,-8,0,22), C(130,130,150), Enum.TextXAlignment.Left, 9)
            return
        end
        for i, r in ipairs(rows) do
            local p = r.plr
            local txt = string.format("%s (@%s)%s", p.DisplayName, p.Name,
                r.dist < math.huge and string.format("  ·  %d studs", math.floor(r.dist)) or "")
            local b = F.makeBtn(plist, txt, UDim2.new(0,0,0,0), UDim2.new(1,-8,0,24),
                (p == Copy.target) and C(60,160,220) or C(30,28,44), nil, 9)
            b.TextXAlignment = Enum.TextXAlignment.Left
            b.LayoutOrder = i
            b.MouseButton1Click:Connect(function()
                Copy.setTarget(p)
                F.notify("Watching " .. p.DisplayName .. " — COPY MOVES to copy them", "info")
                fillPlayers()
            end)
        end
    end
    search:GetPropertyChangedSignal("Text"):Connect(fillPlayers)
    clearBtn.MouseButton1Click:Connect(function()
        Copy.setTarget(nil)
        fillPlayers()
    end)

    -- ---- what they've played ----
    local function arrowBtn(parent, x, dir, id)
        local b = F.makeBtn(parent, ARROW_SYMBOLS[dir], UDim2.new(1,x,0,6), UDim2.new(0,28,0,28),
            C(30,28,44), ARROW_COLORS[dir].hit, 13)
        b.MouseButton1Click:Connect(function() Copy.assign(id, dir) end)
        return b
    end

    Copy.refresh = function()
        if not slist.Parent then return end
        -- status line
        local tgt = Copy.target
        if tgt then
            local s = "watching " .. tgt.DisplayName .. " (@" .. tgt.Name .. ")"
            if Copy.on then s = "COPYING " .. tgt.DisplayName .. " (@" .. tgt.Name .. ")" end
            if Copy.fill then s = s .. "\nfilling: their next poses go into " .. table.concat(Copy.fill, ", ") end
            selLbl.Text = s
            selLbl.TextColor3 = Copy.on and C(120,255,150) or C(120,220,255)
        else
            selLbl.Text = "nobody picked — choose a player above"
            selLbl.TextColor3 = C(130,130,150)
        end
        paint(copyBtn, Copy.on, "■ STOP COPYING", "▶ COPY MOVES", C(60,190,120))
        paint(walkBtn, Copy.walkToo, "WALK TOO: ON", "WALK TOO: OFF")
        paint(syncBtn, Copy.sync, "SAME FRAME: ON", "SAME FRAME: OFF")
        intoBtn.Text = "PUT INTO: " .. Copy.into
        paint(fillBtn, Copy.fill ~= nil, "FILLING... (stop)", "FILL NEXT 4 POSES", C(255,160,40))

        for _, c in ipairs(slist:GetChildren()) do
            if c:IsA("GuiObject") then c:Destroy() end
        end
        if #Copy.seen == 0 then
            F.makeLabel(slist, tgt and ("Waiting for " .. tgt.DisplayName .. " to play something...")
                or "Pick a player and their animations show up here", UDim2.new(0,0,0,0),
                UDim2.new(1,-8,0,22), C(130,130,150), Enum.TextXAlignment.Left, 9)
            return
        end
        for i, e in ipairs(Copy.seen) do
            local card = Instance.new("Frame")
            card.Size = UDim2.new(1,-8,0,40)
            card.BackgroundColor3 = C(28,26,40); card.BackgroundTransparency = 0.3
            card.BorderSizePixel = 0; card.LayoutOrder = i; card.Parent = slist
            F.uiCorner(card, UDim.new(0,6))
            local nm = F.makeLabel(card, Copy.nameOf(e), UDim2.new(0,8,0,3), UDim2.new(1,-172,0,18),
                C(235,235,245), Enum.TextXAlignment.Left, 10)
            nm.Font = Enum.Font.GothamBold
            nm.TextTruncate = Enum.TextTruncate.AtEnd
            local meta = string.format("%s  ·  %s  ·  ×%d", e.id,
                e.length > 0 and string.format("%.2fs", e.length) or "?s", e.count)
            if e.bad then meta = meta .. "  ·  ⚠ won't play for you here" end
            local ml = F.makeLabel(card, meta, UDim2.new(0,8,0,20), UDim2.new(1,-172,0,16),
                e.bad and C(255,160,90) or C(140,140,160), Enum.TextXAlignment.Left, 9)
            ml.TextTruncate = Enum.TextTruncate.AtEnd

            local id = e.id
            local tryB = F.makeBtn(card, "▷", UDim2.new(1,-162,0,6), UDim2.new(0,28,0,28), C(45,40,70), nil, 12)
            tryB.MouseButton1Click:Connect(function() Copy.try(id) end)
            for k, dir in ipairs(ARROW_ORDER) do
                arrowBtn(card, -130 + (k - 1) * 32, dir, id)
            end
        end
    end

    fillPlayers()
    Copy.refresh()
    -- keep the player list (distances, joins and leaves) fresh while it's on screen
    task.spawn(function()
        while F.alive do
            task.wait(2)
            if not plist.Parent then break end
            if F.vizShown(plist) and not search:IsFocused() then fillPlayers() end
        end
    end)
end

function F.buildTab_Settings(pages)
    local pg6 = pages["⚙ SETTINGS"]

    local legsTitle = F.makeLabel(pg6, "🦵 LEGS ON GROUND (Optional)",
        UDim2.new(0,8,0,8), UDim2.new(1,-16,0,20),
        Color3.fromRGB(255,80,180), Enum.TextXAlignment.Left, 12)
    F.regText(legsTitle)
    F.makeDivider(pg6, 30, Color3.fromRGB(0,200,255))
    F.makeLabel(pg6, "Prevents walking and jumping — character stays planted.",
        UDim2.new(0,8,0,36), UDim2.new(1,-16,0,28),
        Color3.fromRGB(140,140,160), Enum.TextXAlignment.Left, 10)

    local legsBtn = F.makeBtn(pg6, "🔓  LEGS UNLOCKED  (OFF)",
        UDim2.new(0,8,0,68), UDim2.new(1,-16,0,32), Color3.fromRGB(35,35,55), nil, 11)
    legsBtn.MouseButton1Click:Connect(function()
        legsLocked = not legsLocked
        F.applyLegsLock(legsLocked)
        if legsLocked then
            legsBtn.Text = "🔒  LEGS LOCKED  (ON)"
            legsBtn.BackgroundColor3 = THEMES[currentThemeName].accent
        else
            legsBtn.Text = "🔓  LEGS UNLOCKED  (OFF)"
            legsBtn.BackgroundColor3 = Color3.fromRGB(35,35,55)
        end
        F.notify(legsLocked and "Legs locked" or "Legs unlocked", "info")
    end)

    F.makeDivider(pg6, 114, Color3.fromRGB(255,80,180))
    local faceTitle = F.makeLabel(pg6, "😊 DYNAMIC FACE IDs  (per arrow direction)",
        UDim2.new(0,8,0,120), UDim2.new(1,-16,0,20),
        Color3.fromRGB(255,80,180), Enum.TextXAlignment.Left, 12)
    F.regText(faceTitle)
    F.makeLabel(pg6, "Only works if your character has a face decal on its head.",
        UDim2.new(0,8,0,142), UDim2.new(1,-16,0,18),
        Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 10)

    local faceOrder = { "LEFT", "DOWN", "UP", "RIGHT" }
    for i, dir in ipairs(faceOrder) do
        local y = 164 + (i-1)*38
        local col = ARROW_COLORS[dir] and ARROW_COLORS[dir].hit or Color3.fromRGB(255,255,255)
        F.makeLabel(pg6, dir, UDim2.new(0,8,0,y), UDim2.new(0,52,0,28), col, Enum.TextXAlignment.Left)
        local fb = F.makeBox(pg6, UDim2.new(0,66,0,y), UDim2.new(1,-74,0,28), "Face decal ID for "..dir, faceIds[dir])
        local capturedDir = dir
        fb.FocusLost:Connect(function()
            faceIds[capturedDir] = fb.Text:gsub("%D","")
        end)
    end

    F.makeDivider(pg6, 320, Color3.fromRGB(0,200,255))
    local themeTitle = F.makeLabel(pg6, "🎨 THEME", UDim2.new(0,8,0,326), UDim2.new(1,-16,0,20), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Left, 12)
    F.regText(themeTitle)

    local themeNames = { "Pink", "Cyan", "Purple", "RGB", "Mono" }
    local themeSwatch = { Pink = Color3.fromRGB(255,80,180), Cyan = Color3.fromRGB(0,200,255),
                           Purple = Color3.fromRGB(165,85,255), RGB = Color3.fromRGB(255,255,255),
                           Mono = Color3.fromRGB(235,235,240) }
    for i, tn in ipairs(themeNames) do
        local tx = 8 + (i-1) * 82
        local tbtn = F.makeBtn(pg6, tn, UDim2.new(0, tx, 0, 356), UDim2.new(0, 76, 0, 32), themeSwatch[tn], Color3.fromRGB(20,20,20), 10)
        tbtn.MouseButton1Click:Connect(function() F.setTheme(tn) end)
    end

    F.makeDivider(pg6, 400, Color3.fromRGB(0,200,255))
    local rpTitle = F.makeLabel(pg6, "⚔ RP TUG-OF-WAR (PROXIMITY)", UDim2.new(0,8,0,406), UDim2.new(1,-16,0,20), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Left, 12)
    F.regText(rpTitle)
    F.makeLabel(pg6, "Moves you toward the target on every note press.", UDim2.new(0,8,0,428), UDim2.new(1,-16,0,18), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 10)

    local rpBtn = F.makeBtn(pg6, rpModeEnabled and "⚔  RP MODE ON" or "📴  RP MODE OFF",
        UDim2.new(0,8,0,450), UDim2.new(0,160,0,32),
        rpModeEnabled and THEMES[currentThemeName].accent or Color3.fromRGB(35,35,55), nil, 11)
    rpBtn.MouseButton1Click:Connect(function()
        rpModeEnabled = not rpModeEnabled
        if rpModeEnabled then
            rpBtn.Text = "⚔  RP MODE ON"
            rpBtn.BackgroundColor3 = THEMES[currentThemeName].accent
        else
            rpBtn.Text = "📴  RP MODE OFF"
            rpBtn.BackgroundColor3 = Color3.fromRGB(35,35,55)
        end
    end)

    local targetBox = F.makeBox(pg6, UDim2.new(0,176,0,450), UDim2.new(1,-184,0,32), "Target Player Name...")
    targetBox.FocusLost:Connect(function()
        F.setTargetPlayer(targetBox.Text)
    end)

    F.makeLabel(pg6, "SPEED", UDim2.new(0,8,0,490), UDim2.new(0,40,0,22), Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local rpValLbl = F.makeLabel(pg6, string.format("%.1f studs", rpMoveStep), UDim2.new(0,300,0,490), UDim2.new(0,94,0,22), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Right, 11)
    F.regText(rpValLbl)

    F.makeSlider(pg6, UDim2.new(0,50,0,494), UDim2.new(0,250,0,14), 0.5, 5, rpMoveStep, function(v)
        rpMoveStep = v
        rpValLbl.Text = string.format("%.1f studs", v)
    end)

    -- spacing owns 530 through ~1140
    F.buildSpacingUI(pg6, 530)
    -- ============================================================
    -- ── SAVE / LOAD ──
    -- ============================================================
    local svY = 1180
    F.makeDivider(pg6, svY, Color3.fromRGB(120,220,160))
    local svTitle = F.makeLabel(pg6, "SAVE / LOAD", UDim2.new(0,8,0,svY+6),
        UDim2.new(1,-16,0,20), Color3.fromRGB(120,220,160), Enum.TextXAlignment.Left, 12)
    svTitle.Font = Enum.Font.GothamBold

    local svStatus = F.makeLabel(pg6, "", UDim2.new(0,8,0,svY+28),
        UDim2.new(1,-16,0,32), Color3.fromRGB(160,160,180), Enum.TextXAlignment.Left, 9)
    svStatus.TextWrapped = true

    -- slot picker
    F.makeLabel(pg6, "SLOT", UDim2.new(0,8,0,svY+66), UDim2.new(0,40,0,26),
        Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local slotBtns = {}
    for s = 1, Save.slots do
        local b = F.makeBtn(pg6, tostring(s), UDim2.new(0, 50 + (s-1) * 46, 0, svY+66),
            UDim2.new(0, 40, 0, 26), Color3.fromRGB(35,35,55), nil, 11)
        slotBtns[s] = b
        b.MouseButton1Click:Connect(function()
            Save.slot = s
            if Save.refreshUI then Save.refreshUI() end
        end)
    end

    local svSave = F.makeBtn(pg6, "SAVE", UDim2.new(0,8,0,svY+100),
        UDim2.new(0,126,0,30), Color3.fromRGB(50,170,110), nil, 11)
    local svLoad = F.makeBtn(pg6, "LOAD", UDim2.new(0,140,0,svY+100),
        UDim2.new(0,126,0,30), Color3.fromRGB(70,120,255), nil, 11)
    local svWipe = F.makeBtn(pg6, "CLEAR SLOT", UDim2.new(0,272,0,svY+100),
        UDim2.new(0,124,0,30), Color3.fromRGB(170,35,35), nil, 10)

    local svAuto = F.makeBtn(pg6, "AUTOSAVE: ON", UDim2.new(0,8,0,svY+138),
        UDim2.new(0,190,0,26), Color3.fromRGB(60,190,120), nil, 9)
    F.makeLabel(pg6, "Checks every 20s, only writes when something changed.",
        UDim2.new(0,206,0,svY+138), UDim2.new(1,-214,0,26), Color3.fromRGB(120,120,140), Enum.TextXAlignment.Left, 9)

    -- clipboard export / import, for executors without file access
    F.makeLabel(pg6, "EXPORT / IMPORT", UDim2.new(0,8,0,svY+176), UDim2.new(1,-16,0,18),
        Color3.fromRGB(120,220,160), Enum.TextXAlignment.Left, 10)
    local ioBox = F.makeBox(pg6, UDim2.new(0,8,0,svY+198), UDim2.new(1,-16,0,30),
        "Paste exported settings here, then press IMPORT")
    ioBox.TextTruncate = Enum.TextTruncate.AtEnd
    local svExport = F.makeBtn(pg6, "EXPORT", UDim2.new(0,8,0,svY+234),
        UDim2.new(0,190,0,28), Color3.fromRGB(45,40,60), nil, 10)
    local svImport = F.makeBtn(pg6, "IMPORT", UDim2.new(0,206,0,svY+234),
        UDim2.new(0,190,0,28), Color3.fromRGB(45,40,60), nil, 10)

    Save.refreshUI = function()
        if not svStatus or not svStatus.Parent then return end
        if Save.available then
            local where = Save.useFolder and (Save.folder .. "/") or ""
            local line = string.format("slot %d  |  saved %s  |  loaded %s  |  %s%s",
                Save.slot, Save.lastSaved, Save.lastLoaded, where,
                Save.exists(Save.slot) and "file exists" or "empty")
            if Save.lastError then line = line .. "\nerror: " .. Save.lastError end
            svStatus.Text = line
            svStatus.TextColor3 = Save.lastError and Color3.fromRGB(255,150,70) or Color3.fromRGB(160,160,180)
        else
            svStatus.Text = "No writefile/readfile in this executor. Use EXPORT/IMPORT below instead."
            svStatus.TextColor3 = Color3.fromRGB(255,150,70)
        end
        for s, b in pairs(slotBtns) do
            b.BackgroundColor3 = (s == Save.slot) and Color3.fromRGB(120,220,160) or Color3.fromRGB(35,35,55)
            b.TextColor3 = (s == Save.slot) and Color3.fromRGB(15,15,20) or Color3.fromRGB(238,238,248)
        end
        svAuto.Text = Save.autoSave and "AUTOSAVE: ON" or "AUTOSAVE: OFF"
        svAuto.BackgroundColor3 = Save.autoSave and Color3.fromRGB(60,190,120) or Color3.fromRGB(35,35,55)
    end

    svSave.MouseButton1Click:Connect(function() Save.write(Save.slot) end)
    svLoad.MouseButton1Click:Connect(function() Save.load(Save.slot) end)
    svWipe.MouseButton1Click:Connect(function() Save.wipe(Save.slot) end)
    svAuto.MouseButton1Click:Connect(function()
        Save.autoSave = not Save.autoSave
        Save.refreshUI()
    end)
    local svTour = F.makeBtn(pg6, "REPLAY THE TOUR", UDim2.new(0,8,0,svY+272),
        UDim2.new(0,190,0,26), Color3.fromRGB(255,190,60), Color3.fromRGB(20,20,25), 10)
    svTour.MouseButton1Click:Connect(function() Intro.startTour() end)

    svExport.MouseButton1Click:Connect(function()
        local json = Save.export()
        if json then ioBox.Text = json end
    end)
    svImport.MouseButton1Click:Connect(function()
        if ioBox.Text == "" then F.notify("Paste an export into the box first", "warn"); return end
        Save.import(ioBox.Text)
    end)

    Save.refreshUI()

    -- ============================================================
    -- ── ARROW HUD ──
    -- ============================================================
    local arY = svY + 310
    F.makeDivider(pg6, arY, Color3.fromRGB(255,110,230))
    local arTitle = F.makeLabel(pg6, "ARROW HUD", UDim2.new(0,8,0,arY+6),
        UDim2.new(1,-16,0,20), Color3.fromRGB(255,110,230), Enum.TextXAlignment.Left, 12)
    arTitle.Font = Enum.Font.GothamBold
    F.makeLabel(pg6, "Drag the arrows anywhere on screen — all four move together as one strip.",
        UDim2.new(0,8,0,arY+26), UDim2.new(1,-16,0,28), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 9)

    local arToggles = {
        { key = "draggable",   on = "DRAG: ON",    off = "DRAG: OFF" },
        { key = "noteEnabled", on = "NOTES: ON",   off = "NOTES: OFF" },
        { key = "trail",       on = "TRAILS: ON",  off = "TRAILS: OFF" },
        { key = "splash",      on = "SPLASH: ON",  off = "SPLASH: OFF" },
        { key = "combo",       on = "COMBO: ON",   off = "COMBO: OFF" },
        { key = "beatBob",     on = "BEAT BOB: ON",off = "BEAT BOB: OFF" },
        { key = "tilt",        on = "LEAN: ON",    off = "LEAN: OFF" },
        { key = "sprites",     on = "FNF SPRITES: ON", off = "FNF SPRITES: OFF" },
        { key = "oppShow",     on = "OPP ARROWS: ON",  off = "OPP ARROWS: OFF" },
    }
    for i, t in ipairs(arToggles) do
        local col = (i - 1) % 3
        local rowN = math.floor((i - 1) / 3)
        local b = F.makeBtn(pg6, Arrows[t.key] and t.on or t.off,
            UDim2.new(0, 8 + col * 132, 0, arY + 58 + rowN * 32),
            UDim2.new(0, 126, 0, 26),
            Arrows[t.key] and Color3.fromRGB(60,190,120) or Color3.fromRGB(35,35,55), nil, 9)
        local ck, on, off = t.key, t.on, t.off
        b.MouseButton1Click:Connect(function()
            Arrows[ck] = not Arrows[ck]
            b.Text = Arrows[ck] and on or off
            b.BackgroundColor3 = Arrows[ck] and Color3.fromRGB(60,190,120) or Color3.fromRGB(35,35,55)
            if ck == "oppShow" then F.refreshOppStrip() end
            if ck == "sprites" then
                -- look in the folder again, so OFF then ON picks up new files
                Skin.reload()
                Chars.meta = nil
                pcall(Chars.refresh, true)
                F.buildArrowHud()
                Health.paintIcons()
                if Skin.missing then
                    F.notify("No arrow sprites in workspace/FNFInjector/sprites — still on the drawn arrows", "warn")
                end
            end
        end)
    end

    local arDirY = arY + 58 + math.ceil(#arToggles / 3) * 32 + 4
    local arDirBtn = F.makeBtn(pg6, "NOTES TRAVEL: DOWN", UDim2.new(0,8,0,arDirY),
        UDim2.new(0,190,0,28), Color3.fromRGB(70,120,255), nil, 10)
    arDirBtn.MouseButton1Click:Connect(function()
        Arrows.noteDir = (Arrows.noteDir == "DOWN") and "UP" or "DOWN"
        arDirBtn.Text = "NOTES TRAVEL: " .. Arrows.noteDir
    end)

    local arReset = F.makeBtn(pg6, "RESET POSITION", UDim2.new(0,206,0,arDirY),
        UDim2.new(0,190,0,28), Color3.fromRGB(170,35,35), nil, 10)
    arReset.MouseButton1Click:Connect(function()
        Arrows.x, Arrows.y, Arrows.offX, Arrows.offY = 0.5, 1, 0, -82
        Arrows.oppX, Arrows.oppY, Arrows.oppOffX, Arrows.oppOffY = 0.5, 1, -400, -82
        if Arrows.container then
            Arrows.container.Position = UDim2.new(0.5, 0, 1, -82)
        end
        if Arrows.oppContainer then
            Arrows.oppContainer.Position = UDim2.new(0.5, -400, 1, -82)
        end
        F.notify("Arrow strips recentred", "info")
    end)

    local arRows = {
        { key = "size",      label = "ARROW SIZE",      min = 30,  max = 120, fmt = "%.0f", rebuild = true },
        { key = "gap",       label = "ARROW SPACING",   min = 0,   max = 60,  fmt = "%.0f", rebuild = true },
        { key = "noteSpeed", label = "NOTE SPEED",      min = 80,  max = 1200,fmt = "%.0f" },
        { key = "noteLife",  label = "NOTE TRAVEL (s)", min = 0.15,max = 1.5, fmt = "%.2f" },
    }
    for i, row in ipairs(arRows) do
        local ry = arDirY + 38 + (i-1) * 42
        F.makeLabel(pg6, row.label, UDim2.new(0,8,0,ry), UDim2.new(0,200,0,18),
            Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
        local vlbl = F.makeLabel(pg6, string.format(row.fmt, Arrows[row.key]),
            UDim2.new(0,306,0,ry), UDim2.new(0,90,0,18), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Right, 10)
        F.regText(vlbl)
        local ck, cfm, rb = row.key, row.fmt, row.rebuild
        F.makeSlider(pg6, UDim2.new(0,8,0,ry+20), UDim2.new(1,-16,0,12),
            row.min, row.max, Arrows[row.key], function(v)
                Arrows[ck] = v
                if ck == "size" then Arrows.hitSize = v * 1.16 end
                vlbl.Text = string.format(cfm, v)
                if rb then F.buildArrowHud() end
            end)
    end
    -- ============================================================
    -- ── HOLD TRAILS ──
    -- ============================================================
    local hnY = arY + 380
    F.makeDivider(pg6, hnY, Color3.fromRGB(255,110,230))
    local hnTitle = F.makeLabel(pg6, "HOLD TRAILS", UDim2.new(0,8,0,hnY+6),
        UDim2.new(1,-16,0,20), Color3.fromRGB(255,110,230), Enum.TextXAlignment.Left, 12)
    hnTitle.Font = Enum.Font.GothamBold
    F.makeLabel(pg6, "Hold a note key and the game's own hold-note trail comes out of that arrow, with its held glow and the hold-cover sparks. Holding also builds health, faster the longer you hold: the HOLD sliders in the health bar settings set how much.",
        UDim2.new(0,8,0,hnY+26), UDim2.new(1,-16,0,40), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 9).TextWrapped = true

    local hnBtn = F.makeBtn(pg6, "HOLD TRAILS ON", UDim2.new(0,8,0,hnY+70),
        UDim2.new(0,250,0,30), Color3.fromRGB(200,70,170), nil, 10)
    hnBtn.MouseButton1Click:Connect(function() Notes.setEnabled(not Notes.enabled) end)

    F.makeLabel(pg6, "KEY", UDim2.new(0,266,0,hnY+70), UDim2.new(0,30,0,30),
        Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local hnKey = F.makeBtn(pg6, Notes.key, UDim2.new(0,298,0,hnY+70),
        UDim2.new(0,64,0,30), Color3.fromRGB(25,35,48), nil, 10)
    hnKey.MouseButton1Click:Connect(function()
        hnKey.Text = "..."; hnKey.BackgroundColor3 = Color3.fromRGB(0,200,255)
        local conn; conn = F.own(UserInputService.InputBegan:Connect(function(inp)
            if inp.KeyCode and inp.KeyCode.Name ~= "Unknown" and not inp.KeyCode.Name:match("Mouse") then
                Notes.key = inp.KeyCode.Name
                hnKey.Text = Notes.key
                hnKey.BackgroundColor3 = Color3.fromRGB(25,35,48)
                if Keys.refresh then Keys.refresh() end
                conn:Disconnect()
            end
        end))
    end)

    local hnGrow = F.makeBtn(pg6, "TRAIL RUNS: " .. Notes.grow, UDim2.new(0,8,0,hnY+108),
        UDim2.new(0,250,0,26), Color3.fromRGB(70,120,255), nil, 9)
    hnGrow.MouseButton1Click:Connect(function()
        Notes.grow = (Notes.grow == "UP") and "DOWN" or "UP"
        hnGrow.Text = "TRAIL RUNS: " .. Notes.grow
        Notes.clear()   -- a trail already out was built for the other way
    end)

    Notes.refreshUI = function()
        if not hnBtn or not hnBtn.Parent then return end
        hnBtn.Text = Notes.enabled and "HOLD TRAILS ON" or "HOLD TRAILS OFF"
        hnBtn.BackgroundColor3 = Notes.enabled and Color3.fromRGB(200,70,170) or Color3.fromRGB(35,35,55)
    end
    Notes.refreshUI()

    local hnRows = {
        { key = "fullTime",   label = "TIME TO FULL LENGTH (s)", min = 0.1, max = 2,   fmt = "%.2f" },
        { key = "startDelay", label = "TAP IGNORED UNDER (s)",   min = 0,   max = 0.4, fmt = "%.2f" },
        { key = "length",     label = "TRAIL LENGTH (px)",       min = 40,  max = 400, fmt = "%.0f" },
    }
    for i, row in ipairs(hnRows) do
        local ry = hnY + 144 + (i-1) * 42
        F.makeLabel(pg6, row.label, UDim2.new(0,8,0,ry), UDim2.new(0,230,0,18),
            Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
        local vlbl = F.makeLabel(pg6, string.format(row.fmt, Notes[row.key]),
            UDim2.new(0,306,0,ry), UDim2.new(0,90,0,18), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Right, 10)
        F.regText(vlbl)
        local ck, cfm = row.key, row.fmt
        F.makeSlider(pg6, UDim2.new(0,8,0,ry+20), UDim2.new(1,-16,0,12),
            row.min, row.max, Notes[row.key], function(v)
                Notes[ck] = v
                vlbl.Text = string.format(cfm, v)
            end)
    end
    -- ============================================================
    -- ── MOBILE ──
    -- ============================================================
    local mbY = hnY + 340
    F.makeDivider(pg6, mbY, Color3.fromRGB(120,220,255))
    local mbTitle = F.makeLabel(pg6, "MOBILE ARROWS", UDim2.new(0,8,0,mbY+6),
        UDim2.new(1,-16,0,20), Color3.fromRGB(120,220,255), Enum.TextXAlignment.Left, 12)
    mbTitle.Font = Enum.Font.GothamBold
    F.makeLabel(pg6, "Big touch arrows along the bottom, split into two pairs like FNF on mobile, in the same style as the PC arrows. Tap, hold, or slide between them.",
        UDim2.new(0,8,0,mbY+26), UDim2.new(1,-16,0,28), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 9).TextWrapped = true

    local mbMode = F.makeBtn(pg6, "", UDim2.new(0,8,0,mbY+58), UDim2.new(0,190,0,28), Color3.fromRGB(35,35,55), nil, 10)
    local mbNote = F.makeLabel(pg6, "", UDim2.new(0,206,0,mbY+58), UDim2.new(1,-214,0,28),
        Color3.fromRGB(120,120,140), Enum.TextXAlignment.Left, 9)
    mbNote.TextWrapped = true
    local modeHelp = {
        AUTO = "Shows on phones and tablets, hides with a keyboard.",
        ON   = "Always shown, even on PC (handy for testing).",
        OFF  = "Never shown.",
    }
    mbMode.MouseButton1Click:Connect(function()
        local order = { "AUTO", "ON", "OFF" }
        Mobile.mode = order[((table.find(order, Mobile.mode) or 1) % #order) + 1]
        Mobile.refresh()
    end)

    local mbStrip = F.makeBtn(pg6, "", UDim2.new(0,8,0,mbY+92), UDim2.new(0,190,0,26), Color3.fromRGB(35,35,55), nil, 9)
    mbStrip.MouseButton1Click:Connect(function()
        Mobile.hideStrip = not Mobile.hideStrip
        Mobile.refresh()
    end)
    F.makeLabel(pg6, "Hold streaks and splashes live on the top strip.",
        UDim2.new(0,206,0,mbY+92), UDim2.new(1,-214,0,26), Color3.fromRGB(120,120,140), Enum.TextXAlignment.Left, 9)

    -- handedness: FNF split, or all four under one thumb
    F.makeLabel(pg6, "LAYOUT", UDim2.new(0,8,0,mbY+124), UDim2.new(1,-16,0,16), Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local layoutBtns = {}
    for i, o in ipairs({ { "SPLIT", "Split (FNF)" }, { "LEFT", "Left-handed" }, { "RIGHT", "Right-handed" } }) do
        local b = F.makeBtn(pg6, o[2], UDim2.new(0, 8 + (i-1) * 132, 0, mbY + 142), UDim2.new(0,126,0,26),
            Color3.fromRGB(35,35,55), nil, 9)
        layoutBtns[o[1]] = b
        b.MouseButton1Click:Connect(function() Mobile.layoutMode = o[1]; Mobile.layout(); Mobile.refreshUI() end)
    end
    local mbHaptic = F.makeBtn(pg6, "", UDim2.new(0,8,0,mbY+174), UDim2.new(0,126,0,26), Color3.fromRGB(35,35,55), nil, 9)
    local mbLand = F.makeBtn(pg6, "", UDim2.new(0,140,0,mbY+174), UDim2.new(0,126,0,26), Color3.fromRGB(35,35,55), nil, 9)
    local mbDesk = F.makeBtn(pg6, "", UDim2.new(0,272,0,mbY+174), UDim2.new(0,126,0,26), Color3.fromRGB(35,35,55), nil, 9)
    mbHaptic.MouseButton1Click:Connect(function()
        Mobile.haptics = not Mobile.haptics
        if Mobile.haptics then Mobile.buzz() end
        Mobile.refreshUI()
    end)
    mbLand.MouseButton1Click:Connect(function() Mobile.landscape = not Mobile.landscape; Mobile.refresh() end)
    mbDesk.MouseButton1Click:Connect(function() Mobile.hideDesktop = not Mobile.hideDesktop; Mobile.refresh() end)
    local mbExtraNote = F.makeLabel(pg6, "", UDim2.new(0,8,0,mbY+204), UDim2.new(1,-16,0,28),
        Color3.fromRGB(120,120,140), Enum.TextXAlignment.Left, 9)
    mbExtraNote.TextWrapped = true

    Mobile.refreshUI = function()
        if not mbMode.Parent then return end
        for k, b in pairs(layoutBtns) do
            b.BackgroundColor3 = (k == Mobile.layoutMode) and Color3.fromRGB(60,160,220) or Color3.fromRGB(35,35,55)
        end
        local function paintT(b, on, txt)
            b.Text = txt .. (on and ": ON" or ": OFF")
            b.BackgroundColor3 = on and Color3.fromRGB(60,160,220) or Color3.fromRGB(35,35,55)
        end
        paintT(mbHaptic, Mobile.haptics, "VIBRATE")
        paintT(mbLand, Mobile.landscape, "LANDSCAPE")
        paintT(mbDesk, Mobile.hideDesktop, "TIDY UI")
        local sup = Mobile.hapticSupport() ~= nil
        mbExtraNote.Text = (sup and "Vibration works on this device. "
            or "This device doesn't report vibration support, so VIBRATE does nothing here. ")
            .. "TIDY UI hides the keybind list and starts with the menu folded."
        mbMode.Text = "MOBILE ARROWS: " .. Mobile.mode
        mbMode.BackgroundColor3 = (Mobile.mode == "OFF") and Color3.fromRGB(35,35,55) or Color3.fromRGB(60,160,220)
        mbNote.Text = (modeHelp[Mobile.mode] or "") .. (Mobile.active and "  (showing)" or "")
        mbStrip.Text = Mobile.hideStrip and "HIDE TOP STRIP: ON" or "HIDE TOP STRIP: OFF"
        mbStrip.BackgroundColor3 = Mobile.hideStrip and Color3.fromRGB(60,160,220) or Color3.fromRGB(35,35,55)
    end
    Mobile.refreshUI()

    local mbRows = {
        { key = "size",     label = "ARROW SIZE",           min = 0.5, max = 1.8, fmt = "%.2f" },
        { key = "spread",   label = "GAP BETWEEN PAIRS",    min = 0,   max = 0.6, fmt = "%.2f" },
        { key = "pairGap",  label = "GAP INSIDE A PAIR",    min = 0,   max = 80,  fmt = "%.0f px" },
        { key = "bottom",   label = "HEIGHT FROM BOTTOM",   min = 0,   max = 260, fmt = "%.0f px" },
        { key = "idleFade", label = "SEE-THROUGH WHEN IDLE", min = 0,  max = 0.8, fmt = "%.2f" },
    }
    for i, row in ipairs(mbRows) do
        local ry = mbY + 240 + (i-1) * 42
        F.makeLabel(pg6, row.label, UDim2.new(0,8,0,ry), UDim2.new(0,230,0,18),
            Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
        local vlbl = F.makeLabel(pg6, string.format(row.fmt, Mobile[row.key]),
            UDim2.new(0,306,0,ry), UDim2.new(0,90,0,18), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Right, 10)
        F.regText(vlbl)
        local ck, cfm = row.key, row.fmt
        F.makeSlider(pg6, UDim2.new(0,8,0,ry+20), UDim2.new(1,-16,0,12),
            row.min, row.max, Mobile[row.key], function(v)
                Mobile[ck] = v
                vlbl.Text = string.format(cfm, v)
                Mobile.layout()
                if ck == "idleFade" then
                    for d in pairs(Mobile.btns) do
                        if (Mobile.held[d] or 0) == 0 then Mobile.paint(d, false) end
                    end
                end
            end)
    end

    -- ── menu size ──
    local msY = mbY + 462
    F.makeDivider(pg6, msY, Color3.fromRGB(255,255,255))
    local msTitle = F.makeLabel(pg6, "MENU SIZE", UDim2.new(0,8,0,msY+6),
        UDim2.new(1,-16,0,20), Color3.fromRGB(235,235,245), Enum.TextXAlignment.Left, 12)
    msTitle.Font = Enum.Font.GothamBold
    F.makeLabel(pg6, "AUTO shrinks this panel to fit small screens like phones. The slider makes it bigger or smaller on top of that.",
        UDim2.new(0,8,0,msY+26), UDim2.new(1,-16,0,28), Color3.fromRGB(130,130,150), Enum.TextXAlignment.Left, 9).TextWrapped = true

    local msAuto = F.makeBtn(pg6, "", UDim2.new(0,8,0,msY+58), UDim2.new(0,190,0,28), Color3.fromRGB(35,35,55), nil, 10)
    local msNow = F.makeLabel(pg6, "", UDim2.new(0,206,0,msY+58), UDim2.new(1,-214,0,28),
        Color3.fromRGB(160,160,180), Enum.TextXAlignment.Left, 10)
    msAuto.MouseButton1Click:Connect(function()
        Menu.auto = not Menu.auto
        Menu.fit()
    end)
    Menu.refreshUI = function()
        if not msAuto.Parent then return end
        msAuto.Text = Menu.auto and "AUTO FIT: ON" or "AUTO FIT: OFF"
        msAuto.BackgroundColor3 = Menu.auto and Color3.fromRGB(60,160,220) or Color3.fromRGB(35,35,55)
        msNow.Text = string.format("showing at %d%%", math.floor(Menu.current * 100 + 0.5))
    end
    Menu.refreshUI()

    F.makeLabel(pg6, "SIZE", UDim2.new(0,8,0,msY+94), UDim2.new(0,200,0,18),
        Color3.fromRGB(160,160,160), Enum.TextXAlignment.Left, 10)
    local msVal = F.makeLabel(pg6, string.format("%.2fx", Menu.scale), UDim2.new(0,306,0,msY+94),
        UDim2.new(0,90,0,18), Color3.fromRGB(255,80,180), Enum.TextXAlignment.Right, 10)
    F.regText(msVal)
    F.makeSlider(pg6, UDim2.new(0,8,0,msY+114), UDim2.new(1,-16,0,12), 0.5, 1.5, Menu.scale, function(v)
        Menu.scale = v
        msVal.Text = string.format("%.2fx", v)
        Menu.fit()
    end)

end

function F.buildGUI()
    local old = PlayerGui:FindFirstChild("FNFInjectorGui")
    if old then old:Destroy() end
    -- a rebuilt panel always starts open; without this a panel that was
    -- folded before a load / import came back open but still counted as shut
    guiVisible = true

    local sg = F.own(Instance.new("ScreenGui"))
    sg.Name = "FNFInjectorGui"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = F.silZ(100)   -- above the video backdrop and stage layers
    sg.Parent = PlayerGui

    notifyContainer = Instance.new("Frame")
    notifyContainer.Size = UDim2.new(0, 260, 1, -20)
    notifyContainer.Position = UDim2.new(1, -270, 0, 10)
    notifyContainer.BackgroundTransparency = 1
    notifyContainer.Parent = sg
    local notifyLayout = Instance.new("UIListLayout")
    notifyLayout.SortOrder = Enum.SortOrder.LayoutOrder
    notifyLayout.Padding = UDim.new(0, 6)
    notifyLayout.Parent = notifyContainer

    local MAIN_W, MAIN_H = 440, 620
    local main = Instance.new("Frame")
    main.Name = "Main"; main.Size = UDim2.new(0,MAIN_W,0,MAIN_H)
    main.Position = UDim2.new(0,60,0,60)
    main.BackgroundColor3 = Color3.fromRGB(13, 12, 19)
    main.BackgroundTransparency = 0.04
    main.BorderSizePixel = 0; main.Active = true; main.Draggable = true
    main.ClipsDescendants = true
    main.Parent = sg; F.uiCorner(main, UDim.new(0,18))
    local mainStroke = F.uiStroke(main, Color3.fromRGB(255,255,255), 1)
    mainStroke.Transparency = 0.85
    local mainAccentStroke = Instance.new("UIStroke")
    mainAccentStroke.Color = Color3.fromRGB(255,80,180)
    mainAccentStroke.Thickness = 1; mainAccentStroke.Transparency = 0.7
    mainAccentStroke.Parent = main
    F.regStroke(mainAccentStroke)
    local mainGrad = Instance.new("UIGradient")
    mainGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(26, 22, 38)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(13, 12, 19)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(10, 9, 15)),
    })
    mainGrad.Rotation = 115; mainGrad.Parent = main

    notesLayer = Instance.new("Frame")
    notesLayer.Size = UDim2.new(1,0,1,0); notesLayer.BackgroundTransparency = 1
    notesLayer.ClipsDescendants = true; notesLayer.ZIndex = F.silZ(0); notesLayer.Parent = main

    crtOverlay = Instance.new("Frame")
    crtOverlay.Size = UDim2.new(1,0,1,0); crtOverlay.BackgroundColor3 = Color3.fromRGB(20,255,120)
    crtOverlay.BackgroundTransparency = 0.88
    crtOverlay.BorderSizePixel = 0; crtOverlay.ZIndex = F.silZ(50)
    crtOverlay.Visible = false
    crtOverlay.Parent = main
    local crtOverlayCorner = Instance.new("UICorner"); crtOverlayCorner.CornerRadius = UDim.new(0,10); crtOverlayCorner.Parent = crtOverlay

    local scanlineHolder = Instance.new("Frame")
    scanlineHolder.Size = UDim2.new(1,0,1,0); scanlineHolder.BackgroundTransparency = 1
    scanlineHolder.ClipsDescendants = true; scanlineHolder.ZIndex = F.silZ(51)
    scanlineHolder.Parent = crtOverlay
    local SCANLINE_GAP = 4
    for y = 0, 700, SCANLINE_GAP do
        local line = Instance.new("Frame")
        line.Size = UDim2.new(1,0,0,1)
        line.Position = UDim2.new(0,0,0,y)
        line.BackgroundColor3 = Color3.fromRGB(0,0,0)
        line.BackgroundTransparency = 0.55
        line.BorderSizePixel = 0
        line.ZIndex = F.silZ(51)
        line.Parent = scanlineHolder
    end

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1,0,0,40)
    titleBar.BackgroundColor3 = Color3.fromRGB(19, 17, 27)
    titleBar.BackgroundTransparency = 0.15
    titleBar.BorderSizePixel = 0; titleBar.Parent = main; F.uiCorner(titleBar, UDim.new(0,18))

    -- accent dot, left of the title
    local tbDot = Instance.new("Frame")
    tbDot.Size = UDim2.new(0, 8, 0, 8); tbDot.Position = UDim2.new(0, 14, 0.5, -4)
    tbDot.BackgroundColor3 = Color3.fromRGB(255, 80, 180)
    tbDot.BorderSizePixel = 0; tbDot.Parent = titleBar
    F.uiCorner(tbDot, UDim.new(1, 0)); F.regBg(tbDot)
    -- accent hairline under the header
    local tbSep = Instance.new("Frame")
    tbSep.Size = UDim2.new(1,0,0,1); tbSep.Position = UDim2.new(0,0,1,-1)
    tbSep.BackgroundColor3 = Color3.fromRGB(255,80,180)
    tbSep.BackgroundTransparency = 0.55
    tbSep.BorderSizePixel = 0; tbSep.Parent = titleBar
    F.regBg(tbSep)

    local titleLbl = F.makeLabel(titleBar, "FNF ANIM INJECTOR",
        UDim2.new(0,30,0,0), UDim2.new(0,190,1,0),
        Color3.fromRGB(242,242,250), Enum.TextXAlignment.Left, 13)
    titleLbl.Font = Enum.Font.GothamBold

    -- version chip
    local verChip = Instance.new("Frame")
    verChip.Size = UDim2.new(0, 38, 0, 18); verChip.Position = UDim2.new(0, 196, 0.5, -9)
    verChip.BackgroundColor3 = Color3.fromRGB(255, 80, 180)
    verChip.BackgroundTransparency = 0.78
    verChip.BorderSizePixel = 0; verChip.Parent = titleBar
    F.uiCorner(verChip, UDim.new(1, 0)); F.regBg(verChip)
    local verLbl = F.makeLabel(verChip, "v" .. INJECTOR_VERSION, UDim2.new(0,0,0,0), UDim2.new(1,0,1,0),
        Color3.fromRGB(255,255,255), Enum.TextXAlignment.Center, 9)
    verLbl.Font = Enum.Font.GothamBold

    local toggleBtn = F.makeBtn(titleBar, "HIDE",
        UDim2.new(1,-70,0,8), UDim2.new(0,58,0,24), Color3.fromRGB(34,31,46), nil, 10)

    -- UNLOAD: removes the script and puts the game back. Two clicks, so a
    -- stray one while dragging the panel can't end your session.
    local unloadBtn = F.makeBtn(titleBar, "UNLOAD",
        UDim2.new(1,-138,0,8), UDim2.new(0,62,0,24), Color3.fromRGB(34,31,46), nil, 10)
    local unloadArmed = -math.huge
    unloadBtn.MouseButton1Click:Connect(function()
        if os.clock() - unloadArmed < 3 then
            F.unload("UNLOAD button")
            return
        end
        unloadArmed = os.clock()
        unloadBtn.Text = "SURE?"
        unloadBtn.BackgroundColor3 = Color3.fromRGB(170, 50, 70)
        task.delay(3, function()
            if unloadBtn.Parent and os.clock() - unloadArmed >= 3 then
                unloadBtn.Text = "UNLOAD"
                unloadBtn.BackgroundColor3 = Color3.fromRGB(34,31,46)
            end
        end)
    end)

    local TAB_H = 36
    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1,-8,0,TAB_H); tabBar.Position = UDim2.new(0,4,0,42)
    tabBar.BackgroundTransparency = 1
    tabBar.BorderSizePixel = 0; tabBar.Parent = main
    local tabScroll = Instance.new("ScrollingFrame")
    tabScroll.Size = UDim2.new(1,0,1,0); tabScroll.BackgroundTransparency = 1
    tabScroll.ScrollBarThickness = 0; tabScroll.BorderSizePixel = 0
    tabScroll.CanvasSize = UDim2.new(0,0,1,0); tabScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
    tabScroll.ScrollingDirection = Enum.ScrollingDirection.X
    tabScroll.Parent = tabBar
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0,4); tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    tabLayout.Parent = tabScroll
    local tabPad = Instance.new("UIPadding")
    tabPad.PaddingLeft = UDim.new(0,4); tabPad.PaddingRight = UDim.new(0,4)
    tabPad.Parent = tabScroll

    local contentArea = Instance.new("Frame")
    contentArea.Size = UDim2.new(1,0,1,-(42+TAB_H+4))
    contentArea.Position = UDim2.new(0,0,0,42+TAB_H+4)
    contentArea.BackgroundTransparency = 1; contentArea.Parent = main

    local tabNames   = { "📋 BINDS", "👯 COPY", "💪 ARMS", "🎭 STAGE", "✂ CUTTER", "🎥 CAM", "✈ FLY", "🎬 MAKER", "👁 PREVIEW", "❤ FAVES", "🎶 LIST", "🎛 FX", "🎞 VIDEO", "🏆 RESULT", "✨ SHOW", "⚙ SETTINGS" }
    local pages      = {}
    local tabButtons = {}

    for i, name in ipairs(tabNames) do
        local page = Instance.new("ScrollingFrame")
        page.Size = UDim2.new(1,0,1,0); page.BackgroundTransparency = 1
        page.ScrollBarThickness = 3; page.ScrollBarImageTransparency = 0.5
        page.CanvasSize = UDim2.new(0,0,0,0)
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.Visible = (i == 1); page.Parent = contentArea
        pages[name] = page

        local tb = Instance.new("TextButton")
        tb.Size = UDim2.new(0,0,0,30); tb.AutomaticSize = Enum.AutomaticSize.X
        tb.BackgroundColor3 = Color3.fromRGB(24, 22, 33)
        tb.BackgroundTransparency = i == 1 and 0.1 or 0.65
        tb.Text = name
        tb.TextColor3 = i == 1 and Color3.fromRGB(255,255,255) or Color3.fromRGB(150,150,170)
        tb.Font = Enum.Font.GothamBold; tb.TextSize = 9
        tb.BorderSizePixel = 0; tb.AutoButtonColor = false
        tb.Parent = tabScroll
        F.uiCorner(tb, UDim.new(0,7))
        local tbTextPad = Instance.new("UIPadding")
        tbTextPad.PaddingLeft = UDim.new(0,11); tbTextPad.PaddingRight = UDim.new(0,11)
        tbTextPad.Parent = tb

        -- accent underline marks the active tab
        local tbLine = Instance.new("Frame")
        tbLine.Name = "ActiveLine"
        tbLine.Size = UDim2.new(1,-16,0,2); tbLine.Position = UDim2.new(0,8,1,-3)
        tbLine.BackgroundColor3 = THEMES[currentThemeName].accent
        tbLine.BackgroundTransparency = i == 1 and 0 or 1
        tbLine.BorderSizePixel = 0; tbLine.Parent = tb
        F.uiCorner(tbLine, UDim.new(1,0)); F.regBg(tbLine)

        tabButtons[name] = tb
        tb.MouseButton1Click:Connect(function()
            for n, p in pairs(pages) do p.Visible = (n == name) end
            for n, btn in pairs(tabButtons) do
                local isActive = (n == name)
                TweenService:Create(btn, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
                    BackgroundTransparency = isActive and 0.1 or 0.65,
                    TextColor3 = isActive and Color3.fromRGB(255,255,255) or Color3.fromRGB(150,150,170),
                }):Play()
                local line = btn:FindFirstChild("ActiveLine")
                if line then
                    TweenService:Create(line, TweenInfo.new(0.18), {
                        BackgroundTransparency = isActive and 0 or 1
                    }):Play()
                end
            end
        end)
    end

    -- lets the tour (and anything else) switch tabs from code
    F.tabButtons = tabButtons
    F.selectTab = function(name)
        if not pages[name] then return end
        for n, p in pairs(pages) do p.Visible = (n == name) end
        for n, btn in pairs(tabButtons) do
            local isActive = (n == name)
            TweenService:Create(btn, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
                BackgroundTransparency = isActive and 0.1 or 0.65,
                TextColor3 = isActive and Color3.fromRGB(255,255,255) or Color3.fromRGB(150,150,170),
            }):Play()
            local line = btn:FindFirstChild("ActiveLine")
            if line then
                TweenService:Create(line, TweenInfo.new(0.18), { BackgroundTransparency = isActive and 0 or 1 }):Play()
            end
        end
    end

    -- one tab failing to build mustn't stop the tabs after it from building
    for _, tab in ipairs({
        { "BINDS", F.buildTab_Binds }, { "COPY", F.buildTab_Copy }, { "ARMS", F.buildTab_Arms },
        { "STAGE", F.buildTab_Stage }, { "CUTTER", F.buildTab_Cutter }, { "CAM", F.buildTab_Cam },
        { "FLY", F.buildTab_Fly }, { "MAKER", F.buildTab_Maker }, { "PREVIEW", F.buildTab_Preview },
        { "FAVES", F.buildTab_Favorites }, { "LIST", F.buildTab_Playlist }, { "FX", F.buildTab_FX },
        { "VIDEO", F.buildTab_Video }, { "RESULT", F.buildTab_Result }, { "SHOW", F.buildTab_Show },
        { "SETTINGS", F.buildTab_Settings },
    }) do
        local okTab, tabErr = pcall(tab[2], pages)
        if not okTab then
            F.log("the " .. tab[1] .. " tab failed to build: " .. tostring(tabErr))
            F.notify("The " .. tab[1] .. " tab hit an error while building — the other tabs still work", "error")
        end
    end

    F.setPanelOpen = function(open)
        if guiVisible ~= open then
            guiVisible = open
            toggleBtn.Text = guiVisible and "HIDE" or "SHOW"
            main.Size = UDim2.new(0, MAIN_W, 0, guiVisible and MAIN_H or 40)
        end
    end

    toggleBtn.MouseButton1Click:Connect(function()
        guiVisible = not guiVisible
        toggleBtn.Text = guiVisible and "HIDE" or "SHOW"
        local targetSize
        if guiVisible then
            targetSize = UDim2.new(0, MAIN_W, 0, MAIN_H)
        else
            targetSize = UDim2.new(0, MAIN_W, 0, 40)
        end
        TweenService:Create(main, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = targetSize
        }):Play()
    end)

    F.startVisualizerLoops()
    Menu.W, Menu.H = MAIN_W, MAIN_H
    Menu.attach(main)
    F.notify("FNF Injector v" .. INJECTOR_VERSION .. " loaded", "success")

    return sg
end

-- ============================================================
--  UNLOAD — hand the game back
--  F.unload calls this before it removes the script's connections
--  and GUIs. Each feature that changed your character, the camera
--  or Roblox's own UI is switched off through its own exit, so it
--  restores exactly what it saved. Every step is isolated: one
--  failing never stops the rest.
-- ============================================================
function F.teardown()
    -- keep whatever you changed this session
    pcall(function()
        if Save.autoSave and Save.available then Save.write(Save.slot, true) end
    end)

    pcall(Arms.relax)             -- arms back into the pose
    pcall(function() RunService:UnbindFromRenderStep("FNFArmsView") end)

    pcall(function() if Boss.active then Boss.exit() end end)
    pcall(function() if Cutscene.active then Cutscene.exit() end end)
    pcall(function() if Ride.enabled then Ride.unlock() end end)
    pcall(function() if Fly.enabled then Fly.stop() end end)
    pcall(function() Air.stop(); Air.unbindFoe(); Air.dropHud() end)
    pcall(function() Copy.setTarget(nil) end)
    pcall(Vid.stopStage)
    pcall(Vid.stop)
    pcall(function() Chaos.setEnabled(false) end)
    pcall(function() FNFCamera:SetBeatZoom(false) end)
    pcall(function() if Health.syncRoblox then Health.releaseRoblox() end end)
    pcall(function() Mobile.applyExtras(false) end)   -- screen orientation
    pcall(function() if legsLocked then F.applyLegsLock(false) end end)
    pcall(function() F.releaseHeldRows() end)
    pcall(F.restoreFace)
    pcall(Sil.clearAll)
    pcall(function() if spacing then spacing:Destroy(); spacing = nil end end)
    pcall(F.stopWatchingTargetAnims)
    pcall(F.stopProximityBlock)
    pcall(F.stopPlaylist)
    pcall(F.stopSequence)
    pcall(function() RunService:UnbindFromRenderStep(Ride.bindName) end)
    pcall(function() RunService:UnbindFromRenderStep("FNFVideoStage") end)

    -- every animation we loaded; Roblox's own (walk, idle, emotes) are untouched
    pcall(function() Hold.clear(false) end)
    pcall(function() for _, tr in pairs(Pose.cache) do tr:Stop(0.1) end end)
    pcall(function() for _, tr in pairs(Cut.tracks) do tr:Stop(0.1) end end)
    pcall(function() if Result.winTrack then Result.winTrack:Stop(0.1) end end)
    pcall(function() if Result.sitTrack then Result.sitTrack:Stop(0.1) end end)
    pcall(F.cleanupAll)

    -- only give the camera back if we were the one holding it
    pcall(function() if FNFCamera.enabled then FNFCamera:SetEnabled(false) end end)

    pcall(function()
        LocalPlayer:SetAttribute(SCRIPT_TAG_ATTR, nil)
        LocalPlayer:SetAttribute(SCRIPT_VERSION_ATTR, nil)
    end)
end

-- ============================================================
--  LAUNCH
-- ============================================================
FNFCamera:BuildLetterbox(PlayerGui)
FNFCamera:Start()

-- load settings FIRST so every piece of UI below is built from them
pcall(Save.boot)
pcall(Lib.load)                -- saved idles and cutter slots
pcall(Vid.resolveApi)
pcall(Intro.startLoading)

F.buildArrowHud()
pcall(function() Chaos.build() end)
pcall(function() Ride.buildWind() end)
pcall(function() Health.build(); Health.start(); Health.setIcons(Health.playerIcon, Health.oppIcon) end)
pcall(function() Keys.build() end)
F.setIdleBPM(idleBPM)
F.buildGUI()
pcall(function() F.setTheme(currentThemeName) end)

Save.startAuto()
Notes.start()
pcall(Mobile.start)
pcall(Cam2.hookOpponent)
pcall(Health.startPortraits)
pcall(Chars.refresh)          -- BF and GF, if they're switched on
F.own(RunService.RenderStepped:Connect(function() pcall(SilFX.stepSpot) end))
pcall(Intro.finishBoot)

if LocalPlayer.Character then task.spawn(F.setupCharacter, LocalPlayer.Character) end
F.own(LocalPlayer.CharacterAdded:Connect(function(c) task.spawn(F.setupCharacter, c) end))

-- alt-tabbing away swallows the key-up: let go of anything still held
F.own(UserInputService.WindowFocusReleased:Connect(function() F.releaseHeldRows() end))

task.spawn(F.setupMusicRemote)
task.spawn(F.setupMatchRemote)
F.broadcastScriptPresence()

if F.replacedOld then
    F.notify("Replaced the copy that was already running", "info")
elseif F.legacyCopy then
    F.notify("A copy from before v7 is still running underneath. Rejoin once to clear it.", "warn")
end
if Skin.missing then
    F.notify("FNF SPRITES is on but workspace/FNFInjector/sprites has no arrows — using the drawn ones", "warn")
end

print("[FNF] Injector v" .. INJECTOR_VERSION .. " fully loaded, boss man.")