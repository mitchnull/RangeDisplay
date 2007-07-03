NOTE: RangeDisplay's original name was RangeCheck, but due to a naming
conflict and some user confusion I renamed it.  If you have RangeCheck
installed, remove that prior to installing RangeDisplay.

Description:

  RangeDisplay is a simple range display addon.  It is using spell range
and interact-distance based checks to determine the approximate range to
your current target.  If, for example, a mage's Arcane Missile spell is
in range, but the character is out of follow-range (an interact distance
based range), the addon will display 28 - 30. 

RangeDisplay is just a front-end to RangeCheck-1.0, a library addon to
calculate the range estimates.

Options:

/rangedisplay enable
  enables RangeDisplay
/rangedisplay disable
  disables RangeDisplay
/rangedisplay unlock
  unlocks the RangeDisplay display frame, so you can drag it to a
  position you like
/rangedisplay lock
  locks the RangeDisplay display frame
/rangedisplay fontsize NUM
  sets the font size of the RangeDisplay display to NUM
/rangedisplay togglesor
  toggles the ShowOutOfRange setting; if it is on, out of range will be
  displayed as "40 +" (for example), instead of hiding the display
/rangedisplay togglecv
  toggles the CheckVisible setting; if it is on, 'visibility' range will
  be the max range displayed (~100 yd) 
/rangedisplay config
  open one of the config GUIs, if available
/rangedisplay configdd
  open the Dewdrop config GUI, if available
/rangedisplay configwf
  open the Waterfall config GUI, if available
/rangedisplay reset
  resets the configuration for this character to default values

Install instructions:

  There are two options for installing RangeDisplay: using embedded
libraries, and using standalon ACE2 libs.  If you want to install
without externals, download the "-noext.zip" version. In this case
you'll need to install the following ACE2 libraries separately:

- Ace2
- Babble-2.2
- GratuityLib
- RangeCheck-1.0

If you want to use the GUI config, you have to install one of these
addons, too:

- DewdropLib
- Waterfall-1.0

After installing, RangeDisplay will be enabled by default, and unlocked,
so you'll see a semi-transparent rectangle in the center of your UI that
you can drag to a position you like.  After finding a good place for it
you should lock the frame with "/rangedisplay lock", so that it won't
eat your mouse clicks.

The original forum for RangeDisplay (and RangeCheck-1.0) is at
http://www.wowace.com/forums/index.php?topic=6664
