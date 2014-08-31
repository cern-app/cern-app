#!/usr/bin/perl -w
#
# Take the gplv2 file in the current directory and create the License files for
# in the Settings.bundle. Run again whenever the file is updated.
#
use strict;

my $out = "../Settings.bundle/en.lproj/License.strings";
my $plistout =  "../Settings.bundle/License.plist";

unlink $out;

open(my $outfh, '>', $out) or die $!;
open(my $plistfh, '>', $plistout) or die $!;

print $plistfh <<'EOD';
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
        <key>StringsTable</key>
        <string>License</string>
        <key>PreferenceSpecifiers</key>
        <array>
EOD
for my $i (sort glob("gplv2"))
{
    my $value=`cat $i`;
    $value =~ s/\r//g;
    $value =~ s/\n/\r/g;
    $value =~ s/[ \t]+\r/\r/g;
    $value =~ s/\"/\'/g;
    my $key=$i;
    $key =~ s/\.txt$//;

    my $cnt = 1;
    my $keynum = $key;
    for my $str (split /\r\r/, $value)
    {
        print $plistfh <<"EOD";
                <dict>
                        <key>Type</key>
                        <string>PSGroupSpecifier</string>
                        <key>FooterText</key>
                        <string>$keynum</string>
                </dict>
EOD

        print $outfh "\"$keynum\" = \"$str\";\n";
        $keynum = $key.(++$cnt);
    }
}

print $plistfh <<'EOD';
        </array>
</dict>
</plist>
EOD
close($outfh);
close($plistfh);
