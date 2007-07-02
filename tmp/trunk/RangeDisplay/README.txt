NOTE: RangeDisplay's original name was RangeCheck, but due to a naming conflict and some user confusion I renamed it.  If you have RangeCheck installed, remove that prior to installing RangeDisplay.

Description:

  RangeDisplay is a simple range display addon.  It is using spell range and interact-distance based checks to determine the approximate range to your current target.  If, for example, a mage's Arcane Missile spell is in range, but the character is out of follow-range (an interact distance based range), the addon will display 28 - 30. 

RangeDisplay is just a front-end to RangeCheck-1.0, a library addon to calculate the range estimates.

Options:

/rangecheck on|off
  if enabled, your current estimated range to your target will be displayed
/rangecheck unlock
  unlocks the RangeDisplay display frame, so you can drag it to a position you like
/rangecheck lock
  locks the RangeDisplay display frame
/rangecheck height NUM
  sets the font height of the RangeDisplay display to NUM
/rangecheck reset
  resets the configuration for this character to default values

Install instructions:

  There are two options for installing RangeDisplay: using embedded libraries, and using standalon ACE2 libs.  If you want to install without externals, download the "-noext.zip" version. In this case you'll need to install install the following ACE2 libraries separately:
- Ace2
- Babble-2.2
- Gratuity-2.0
- RangeCheck-1.0

After installing, RangeDisplay will be enabled by default, and unlocked, so you'll see a semi-transparent rectangle in the center of your UI that you can drag to a position you like.  After finding a good place for it you should lock the frame with "/rangecheck lock", so that it won't eat your mouse clicks.

The original forum for RangeDisplay (and RangeCheck-1.0) is at http://www.wowace.com/forums/index.php?topic=6664
