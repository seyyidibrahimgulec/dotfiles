import XMonad
import Data.Maybe (isJust)
import Data.Monoid
import System.Exit
import XMonad.Actions.CycleWS (Direction1D(..), moveTo, shiftTo, WSType(..), nextScreen, prevScreen)
import XMonad.Actions.WithAll (sinkAll, killAll)
import XMonad.Hooks.ManageDocks
import XMonad.Hooks.DynamicLog (dynamicLogWithPP, wrap, xmobarPP, xmobarColor, shorten, PP(..))
import XMonad.Layout.Spacing
import XMonad.Layout.Accordion
import XMonad.Layout.MultiToggle.Instances (StdTransformers(NBFULL, MIRROR, NOBORDERS))
import XMonad.Util.SpawnOnce
import XMonad.Util.Run
import XMonad.Util.EZConfig (additionalKeysP)
import Graphics.X11.ExtraTypes.XF86

import qualified XMonad.StackSet as W
import qualified Data.Map        as M
import qualified XMonad.Layout.MultiToggle as MT (Toggle(..))


myTerminal      = "alacritty"

myEmacs :: String
myEmacs = "emacsclient -c -a 'emacs' "  -- Makes emacs keybindings easier to type

myBrowser :: String
myBrowser = "brave"

-- Whether focus follows the mouse pointer.
myFocusFollowsMouse :: Bool
myFocusFollowsMouse = True

-- Whether clicking on a window to focus also passes the click to the window
myClickJustFocuses :: Bool
myClickJustFocuses = False


windowCount :: X (Maybe String)
windowCount = gets $ Just . show . length . W.integrate' . W.stack . W.workspace . W.current . windowset

myBorderWidth   = 4

myModMask       = mod4Mask

myWorkspaces    = ["1:chat","2:emacs","3:term","4:web","5:video","6:other","7","8","9"]

myNormalBorderColor  = "#dddddd"
myFocusedBorderColor = "#00ab84"

menuBackgroundColor = "#282a36"
menuForegroundColor = "#eff0eb"
menuFontFamily = "Iosevka Aile"
menuArguments = " -i -l 5 -fn '" ++ menuFontFamily ++ "' -nb '" ++ menuBackgroundColor ++ "' -nf '" ++ menuForegroundColor ++ "' -bw 4"


-- Key bindings
myKeys :: [(String, X ())]
myKeys =
  -- launch a terminal
    [ ("M-<Return>", spawn (myTerminal))

    -- launch dmenu
    , ("M-p", spawn ("dmenu_run" ++ menuArguments))

    -- launch clipmenu
    , ("M-u", spawn ("clipmenu" ++ menuArguments))

      -- launch passmenu
    , ("M-i", spawn ("passmenu" ++ menuArguments))

      -- close focused window
    , ("M-c", kill)
    , ("M-S-c", killAll)

    , ("M-S-q", io (exitWith ExitSuccess))
    , ("M-q", spawn "xmonad --recompile; xmonad --restart")

      -- Emacs keybindings
    , ("M-e", spawn (myEmacs))
    , ("M-S-e b", spawn (myEmacs ++ ("--eval '(ibuffer)'")))
    , ("M-S-e d", spawn (myEmacs ++ ("--eval '(dired nil)'")))

      -- launch browser
    , ("M-b", spawn (myBrowser))

      -- Rotate through the available layout algorithms
    , ("M-<Space>", sendMessage NextLayout)
    , ("M-<Tab>", sendMessage (MT.Toggle NBFULL) >> sendMessage ToggleStruts)

      -- Window navigation
    , ("M-m", windows W.focusMaster)
    , ("M-j", windows W.focusDown)
    , ("M-k", windows W.focusUp)
    , ("M-S-m", windows W.swapMaster)
    , ("M-S-j", windows W.swapDown)
    , ("M-S-k", windows W.swapUp)

      -- Floating windows
    , ("M-t", withFocused $ windows . W.sink)
    , ("M-S-t", sinkAll)

      -- Window resizing
    , ("M-h", sendMessage Shrink)
    , ("M-l", sendMessage Expand)

    -- KB_GROUP Workspaces
    , ("M-.", nextScreen)
    , ("M-,", prevScreen)
    , ("M-S-.", shiftTo Next nonNSP >> moveTo Next nonNSP)
    , ("M-S-,", shiftTo Prev nonNSP >> moveTo Prev nonNSP)

      -- control audio
    , ("<XF86AudioLowerVolume>", spawn "pactl set-sink-volume 0 -1.5%")
    , ("<XF86AudioRaiseVolume>", spawn "pactl set-sink-volume 0 +1.5%")
    , ("<XF86AudioMute>", spawn "pactl set-sink-mute 0 toggle")

      -- control brightness
    , ("<XF86MonBrightnessUp>", spawn "sudo xbacklight -inc 10")
    , ("<XF86MonBrightnessDown>", spawn "sudo xbacklight -dec 10")
    ]

    -- The following lines are needed for named scratchpads.
  where nonNSP          = WSIs (return (\ws -> W.tag ws /= "NSP"))
        nonEmptyNonNSP  = WSIs (return (\ws -> isJust (W.stack ws) && W.tag ws /= "NSP"))
--------------------------------------------------------------------------------------------------

-- Mouse bindings
myMouseBindings (XConfig {XMonad.modMask = modm}) = M.fromList $

    -- mod-button1, Set the window to floating mode and move by dragging
    [ ((modm, button1), (\w -> focus w >> mouseMoveWindow w
                                       >> windows W.shiftMaster))

    -- mod-button2, Raise the window to the top of the stack
    , ((modm, button2), (\w -> focus w >> windows W.shiftMaster))

    -- mod-button3, Set the window to floating mode and resize by dragging
    , ((modm, button3), (\w -> focus w >> mouseResizeWindow w
                                       >> windows W.shiftMaster))

    -- you may also bind events to the mouse scroll wheel (button4 and button5)
    ]

------------------------------------------------------------------------
-- Layouts:
myLayout = avoidStruts (tiled ||| Mirror tiled ||| Full ||| Accordion ||| Mirror Accordion)
  where
     -- default tiling algorithm partitions the screen into two panes
     tiled   = Tall nmaster delta ratio

     -- The default number of windows in the master pane
     nmaster = 1

     -- Default proportion of screen occupied by master pane
     ratio   = 1/2

     -- Percent of screen to increment by when resizing panes
     delta   = 3/100

------------------------------------------------------------------------
-- Window rules:
myManageHook = composeAll
    [ className =? "MPlayer"        --> doFloat
    , className =? "Gimp"           --> doFloat
    , className =? "Emacs"          --> doShift "2:emacs"
    , className =? "Alacritty"      --> doShift "3:term"
    , className =? "Brave-browser"  --> doShift "4:web"
    , resource  =? "desktop_window" --> doIgnore
    , resource  =? "kdesktop"       --> doIgnore ]

------------------------------------------------------------------------
-- Event handling

-- * EwmhDesktops users should change this to ewmhDesktopsEventHook
--
-- Defines a custom handler function for X Events. The function should
-- return (All True) if the default handler is to be run afterwards. To
-- combine event hooks use mappend or mconcat from Data.Monoid.
--
myEventHook = mempty

------------------------------------------------------------------------
-- Status bars and logging

-- Perform an arbitrary action on each internal state change or X event.
-- See the 'XMonad.Hooks.DynamicLog' extension for examples.
--
color01 = "#ff6c6b"
color02 = "#51afef"
color03 = "#ecbe7b"

myLogHook proc = dynamicLogWithPP $ xmobarPP
  {  ppOutput = hPutStrLn proc
   , ppCurrent = xmobarColor color01 "" . wrap ("<fc=" ++ color01 ++ ">") "</fc>"
   , ppVisible = xmobarColor color01 ""
   , ppHidden = xmobarColor color02 "" . wrap ("<fc=" ++ color02 ++ ">") "</fc>"
   , ppHiddenNoWindows = xmobarColor color02 ""
   , ppTitle = xmobarColor color03 "" . shorten 35
   , ppSep =  " | "
   , ppExtras  = [windowCount]
   , ppOrder  = \(ws:l:t:ex) -> [ws,l]++ex++[t]
   }

------------------------------------------------------------------------
-- Startup hook
myStartupHook = do
  spawnOnce "nitrogen --restore &"
  spawnOnce "compton &"
  spawnOnce "/usr/bin/emacs --daemon" -- emacs daemon for the emacsclient
  spawnOnce "clipmenud"

------------------------------------------------------------------------
-- Now run xmonad with all the defaults we set up.

-- Run xmonad with the settings you specify. No need to modify this.
--
main = do
  xmproc <- spawnPipe "xmobar"
  xmonad $docks $ defaults xmproc

-- A structure containing your configuration settings, overriding
-- fields in the default config. Any you don't override, will
-- use the defaults defined in xmonad/XMonad/Config.hs
--
-- No need to modify this.
--
defaults xmproc = def {
      -- simple stuff
        terminal           = myTerminal,
        focusFollowsMouse  = myFocusFollowsMouse,
        clickJustFocuses   = myClickJustFocuses,
        borderWidth        = myBorderWidth,
        modMask            = myModMask,
        workspaces         = myWorkspaces,
        normalBorderColor  = myNormalBorderColor,
        focusedBorderColor = myFocusedBorderColor,

      -- key bindings
      --   keys               = myKeys,
        mouseBindings      = myMouseBindings,

      -- hooks, layouts
        layoutHook         = spacingRaw False (Border 0 10 10 10) True (Border 10 10 10 10) True $ myLayout,
        manageHook         = myManageHook,
        handleEventHook    = myEventHook,
        logHook            = myLogHook xmproc,
        startupHook        = myStartupHook
    } `additionalKeysP` myKeys
