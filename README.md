# VP3split

Pfaff embroidery files (VP3 format) can be too large for Essie's Creative 1.5.
It's unknown if the limit is the filesize, or the number of stitches.

To analyze the VP3 file format I mixed info from these sources:
- https://edutechwiki.unige.ch/en/Embroidery_format
- https://edutechwiki.unige.ch/en/Embroidery_format_VP3
- https://community.kde.org/Projects/Liberty/File_Formats/Viking_Pfaff
- http://www.jasonweiler.com/VP3FileFormatInfo.html

and used the Hexinator (https://hexinator.com) tool.
The crappy grammar file I produced is in the `hexinator` subdir.

This utility is written in an utter non-Ruby style.
 