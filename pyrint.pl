#!/usr/bin/perl -w

# (C) 2010 A. Sovijärvi (ari@sovijarvi.fi)
# Distributed under the Perl Artistic License.

# Please see the readme.txt for an apology for the horrible code.

use Gtk2 -init;
use Gtk2::GladeXML;
use Cairo;
use GD;

# depencies; debian/ubuntu-packages:
# libgtk2-perl
# libgtk2-gladexml-perl
# libgd-gd2-perl

sub initialize {
  my $output;
  $output=chr(0x1B).'@';
  $output=$output.chr(0x1B).'iS';
  $output=$output.chr(0x1B).'iR'.chr(0x01);
  return $output;
}

# 0: gd image object
sub processimage {
  my $inputimage=$_[0];
  $inputimage=$inputimage->copyRotate90(); # we turn it 90 degrees before anything else...
  my $charcount;
  my $x;
  my $y;
  my @pixel=();
  my ($width,$height)=$inputimage->getBounds();
  my $pixelgroups;
  my $output="";

  # I found no perfectly working way of turning pango's antialiasing off, so we'll handle
  # the gray -> bw conversion here.
  for ($y=$height-1; $y>-1; $y--) {
    for ($x=$width/8; $x>-1; $x--) {
      my @inpixels=();
      foreach (0..7) {
        my $tmpcolor=$inputimage->getPixel(($x*8)+$_,$y);
        my ($r, $g, $b)=$inputimage->rgb($tmpcolor);
        if ($r<150) { # it's B/W, so we only need to compare one value
          $inpixels[$_]=1;
        } else {
          $inpixels[$_]=0;
        }
      }

      $pixel[$x]=ord(pack('B8', $inpixels[0].$inpixels[1].$inpixels[2].$inpixels[3].$inpixels[4].$inpixels[5].$inpixels[6].$inpixels[7]));
    }

    $output=$output.'G'.chr(($width/8)+4).chr(0x00).chr(0x00).chr(0x00).chr(0x00).chr(0x00);
    for ($pixelgroups=0; $pixelgroups<($width/8); $pixelgroups++) {
      $output=$output.chr($pixel[$pixelgroups]);
    }
  }
  return $output;
}

# 0: amount of extra lines
sub linefeed {
  my $feedcount=$_[0];
  my $output="";

  foreach (0..$feedcount) {
    $output=$output."Z";
  }
  $output=$output.chr(0x1A);
  return $output;
}

# -- CUPS hackery -----------------------------------------------------------

# This is rather ghetto, but I didn't want to 
# add depencies to perl cups modules.

# 0: printer name; if not empty, we'll return the input string's index in list
sub get_printers {
  my $searchname=$_[0];
  my $indexnumber=0;
  my @foundprinters=();
  my @nameline=();
  open($printerlist, "lpstat -a |");
  my @printerresult=<$printerlist>;
  close($printerlist);
  foreach (@printerresult) {
    @nameline=split(" ", $_);
    push(@foundprinters, $nameline[0]);
    if (($searchname ne "") && ($nameline[0] eq $searchname)) {
      last;
    }
    $indexnumber++;
  }
  if ($searchname ne "") {
    return $indexnumber;
  } else {
    return @foundprinters;
  }
}

# -- GUI elements -----------------------------------------------------------
sub kill_editorwindow {
  Gtk2->main_quit;
  &settings("save");
  print "Thanks for using B-label!\n";
}

sub show_about {
  $aboutbox->run;
  $aboutbox->hide;
}

sub fill_printerlist {
  my @printers=&get_printers("");
  my $foundprinters=0;

  foreach (@printers) {
    $foundprinters=1;
    $printerselect->append_text("$_");
  }

  # if we have printers, remove the "not found"-entry
  if ($foundprinters>0) {
    $printerselect->remove_text(0);
    $printerselect->set_active(0);
  }
}

# escapes the couple of characters that make pango go haywire
# 0: text string to sort out
sub escape_characters {
  my $escape_string=$_[0];
  $escape_string =~ s/\&/&amp;/g;
  $escape_string =~ s/\</&lt;/g;
  $escape_string =~ s/\>/&gt;/g;
  return $escape_string;
}

# 0: print mode (0=for printer, 1=for screen), unimplemented at the moment,
#    but will later allow trying out different tape colors in the preview window.
# 1: line 1
# 2: line 2
sub render_text {
  my $printmode=$_[0];
  my $textline1=&escape_characters($_[1]);
  my $textline2=&escape_characters($_[2]);

  my @foreground=(255, 255, 255);
  my @background=(0, 0, 0);
  my $maxwidth=32767;
  my $maxheight=64;
  my $effects1="";
  my $effects2="";
  my $surface=Cairo::ImageSurface->create('rgb24', $maxwidth, $maxheight);
  my $cr=Cairo::Context->create($surface); 

  $cr->rectangle(0, 0, $maxwidth, $maxheight); 
  if ($inverse->get_active) {
    $cr->set_source_rgb(@background); 
  } else {
    $cr->set_source_rgb(@foreground); 
  }
  $cr->fill; 

  my $pango_layout=Gtk2::Pango::Cairo::create_layout($cr); 
  $pango_layout->set_alignment(lc($xalign->get_active_text()));
#  $pango_layout->set_spacing(100); <= doesn't seem to do anything!

  if ($strikethrough1->get_active) { $effects1=$effects1." strikethrough=\"true\""; }
  if ($strikethrough2->get_active) { $effects2=$effects2." strikethrough=\"true\""; }

  if ($underline1->get_active) { $effects1=$effects1." underline=\"single\""; }
  if ($underline2->get_active) { $effects2=$effects2." underline=\"single\""; }

  if (($textline1 eq "") && ($textline2 eq "")) {
    $pango_layout->set_markup("<span $effects1 font=\"".$font1->get_font_name()."\">Preview</span>"); 
    $printbutton->set_sensitive(0);
  } else {
    my $pango_output="";

    if ($textline1 ne "") {
      $pango_output=$pango_output."<span $effects1 font=\"".$font1->get_font_name()."\">".$textline1."</span>";
    }

    if (($textline1 ne "") && ($textline2 ne "")) {
      $pango_output=$pango_output."\n";
    }

    if ($textline2 ne "") {
      $pango_output=$pango_output."<span $effects2 font=\"".$font2->get_font_name()."\">".$textline2."</span>";
    }
    $printbutton->set_sensitive(1);

    $pango_layout->set_markup($pango_output);
  }

  if ($inverse->get_active) {
    $cr->set_source_rgb(@foreground);
  } else {
    $cr->set_source_rgb(@background);
  }

  my ($xsize,$ysize)=$pango_layout->get_pixel_size();

  if ($yalign->get_active()==0) { $cr->move_to(0,0); } # top
  if ($yalign->get_active()==1) { $cr->move_to(0,($maxheight/2)-($ysize/2)); } # middle
  if ($yalign->get_active()==2) { $cr->move_to(0,$maxheight-$ysize); } # bottom

  Gtk2::Pango::Cairo::show_layout($cr, $pango_layout);

  $cr->show_page();

  my $width=$xsize;
  my $height=$surface->get_height;
  my $stride=$surface->get_stride;
  my $data=$surface->get_data;
  my $xpixbuf=Gtk2::Gdk::Pixbuf->new_from_data($data, 'rgb', FALSE, 8, $width, $height, $stride);

  return $xpixbuf;
}

# Reacts to most GUI changes, updates the preview to match the changes.
sub update_preview {
  $preview->set_from_pixbuf(&render_text(1, $line1->get_text, $line2->get_text));
  my $hadj=$previewscroll->get_hadjustment;
  $hadj->set_value($hadj->upper);
  $previewscroll->set_hadjustment($hadj);
}

# Print out the result with more or less ghetto way of passing data from pixbuf to GD.
sub print_all {
  #my $output=&render_text(1, $line1->get_text, $line2->get_text);
  my $output=&render_text(1, $_[0], $_[1]);
  my $pngdata=$output->save_to_buffer("png");

  my $outputimage=GD::Image->newFromPngData($pngdata);
  my $rawdata=&processimage($outputimage);

  #my $printer_to_use = $printerselect->get_active_text();
  my $printer_to_use="Brother-PT-1230PC";

  open(my $printer, "| lpr -P".$printer_to_use);
  binmode $printer;
  print $printer &initialize;
  print $printer $rawdata;
  print $printer &linefeed(5);
  close($printer);
}

# 0: input boolean
sub boolean2int {
  my $boolean=$_[0];
  if ($boolean) {
    return "1";
  } else {
    return "0";
  }
}

# 0: "load" or "save"
sub settings {
  my $mode=$_[0];

  if ($mode eq "save") {
    open(my $settingsfile, "> ".$ENV{HOME}."/.blabel.conf");
    print $settingsfile "# B-label configuration file\n";
    print $settingsfile $font1->get_font_name."\n";
    print $settingsfile $font2->get_font_name."\n";
    print $settingsfile $printerselect->get_active_text()."\n";
    print $settingsfile $xalign->get_active."\n";
    print $settingsfile $yalign->get_active."\n";
    print $settingsfile &boolean2int($inverse->get_active)."\n";
    print $settingsfile &boolean2int($underline1->get_active)."\n";
    print $settingsfile &boolean2int($underline2->get_active)."\n";
    print $settingsfile &boolean2int($strikethrough1->get_active)."\n";
    print $settingsfile &boolean2int($strikethrough2->get_active)."\n";
    close($settingsfile);
  }

  if (($mode eq "load") && (-e $ENV{HOME}."/.blabel.conf" )) {
    open(my $settingsfile, $ENV{HOME}."/.blabel.conf");
    my @settings=<$settingsfile>;
    close($settingsfile);
    chomp(@settings);
    $font1->set_font_name($settings[1]);
    $font2->set_font_name($settings[2]);
    $printerselect->set_active(&get_printers($settings[3]));
    $xalign->set_active($settings[4]);
    $yalign->set_active($settings[5]);
    $inverse->set_active($settings[6]);
    $underline1->set_active($settings[7]);
    $underline2->set_active($settings[8]);
    $strikethrough1->set_active($settings[9]);
    $strikethrough2->set_active($settings[10]);
    &update_preview;
  }
}

sub init_ui {
  our $gladesource=Gtk2::GladeXML->new('pyrint.glade');
  $gladesource->signal_autoconnect_from_package('');
  our $preview=$gladesource->get_widget('preview');

  our $aboutbox=$gladesource->get_widget('aboutdialog');

  our $printerselect=$gladesource->get_widget('printerselect');
  our $printbutton=$gladesource->get_widget('printbutton');
  our $previewscroll=$gladesource->get_widget('previewscroll');
  &fill_printerlist;

  our $line1=$gladesource->get_widget('entry1');
  our $line2=$gladesource->get_widget('entry2');
  our $font1=$gladesource->get_widget('fontselect1');
  our $font2=$gladesource->get_widget('fontselect2');
  our $underline1=$gladesource->get_widget('underline1');
  our $underline2=$gladesource->get_widget('underline2');
  our $strikethrough1=$gladesource->get_widget('strikethrough1');
  our $strikethrough2=$gladesource->get_widget('strikethrough2');

  our $xalign=$gladesource->get_widget('xalign');
  our $yalign=$gladesource->get_widget('yalign');
  our $inverse=$gladesource->get_widget('inversetext');

  $xalign->set_active(0);
  $yalign->set_active(1);

  &settings("load");
}


sub main {
  &init_ui;
  #Gtk2->main;
  print_all $ARGV[0];
}

&main;
