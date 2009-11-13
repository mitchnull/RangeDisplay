Description:

  RangeDisplay is a simple range display addon.  It is using spell range,
item range and interact-distance based checks to determine the approximate
range to your current target.  If, for example, a mage's Arcane Missile spell
is in range, but the character is out of follow-range (an interact distance
based range), the addon will display 28 - 30. 

RangeDisplay is a front-end to LibRangeCheck-2.0, a library addon to
calculate the range estimates. DogTag also supports LibRangeCheck via
the [Range] tag, thus you can get range display in addons using DogTag
to build texts, like PitBull (unit frames) and CowTip (tooltip).

Note: RangeDisplay can only check for some specific distances, thus determining
a minimum and maximum range to the target. Some of these ranges are rather
large, so the range update may be slow, as it takes time to cover a bigger
distance.  Unfortunately there is no way (that I know of) of providing higher
resolution for range estimates.

Options:

/rangedisplay standby
  Toggle RangeDisplay on/off.
/rangedisplay locked
  Toggle the locked state of RangeDisplay frame.
  While unlocked, you can drag it to a position you like with the left mouse
  button and open its DewDrop menu by right-clicking on the frame.
  While it is locked, you can click-thru the display.
/rangedisplay color
  Set the color of the RangeDisplay text.
/rangedisplay font
  Set the font of the RangeDisplay text.
/rangedisplay fontOutline
  Set the outline style for the font of the RangeDisplay text.
/rangedisplay fontSize
  Sets the font size of the RangeDisplay text.
/rangedisplay strata
  Set the frame strata of the RangeDisplay frame.
/rangedisplay outOfRangeDisplay
  Toggle the OutOfRangeDisplay setting. If it is on, out of range will be
  displayed as "40 +" (for example), instead of hiding the display.
/rangedisplay checkVisibility
  Toggle the CheckVisibility setting. If it is on, 'visibility' range will
  be the max range displayed (~100 yd).
/rangedisplay enemyOnly
  Toggle showing the range for enemy players only, or for all units.
/rangedisplay config
  Open the config GUI

Install instructions:

If you want to select different fonts, you also need:

- LibSharedMedia-3.0
- SharedMedia

After installing, RangeDisplay will be enabled by default, and unlocked,
so you'll see a semi-transparent rectangle in the center of your UI that
you can drag to a position you like.  After finding a good place for it
you should lock the frame with "/rangedisplay locked", so that it won't
eat your mouse clicks.

The official release can be downloaded from http://www.wowinterface.com/downloads/info7297
