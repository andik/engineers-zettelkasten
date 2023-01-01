# ===========================================================================
# Markdown Editor Component
# ===========================================================================

namespace eval mdedit {
	variable window_to_content

	# name marker color underline font space
	set linetypes [concat {
		h1     "#"      {}         1         h1     0
		h2     "##"     {}         1         h2     0
		h3     "###"    {}         1         h3     0
		h4     "####"   {}         1         h4     0
		h5     "#####"  {}         1         h5     0
		h6     "######" {}         1         h6     0
		list   "-"      {}         0         {}     5
		quote  ">"      "#0000ff"  0         {}     5
	}]

	# name marker color underline font space
	set taskstates [concat {
		task  "☐"      "#006699"  0         {}     5
		wip   "►"      "#dd4422"  0         {}     5
		wait  "W"      "#884400"  0         {}     5
		done  "✓"      "#448800"  0         {}     5
	}]

	# Description of Syntax and default Display properties
	#	name        pattern         color      underline font space
	variable syntax [concat {                                          
		id         {`[^`]+`}        "#337733"  0         {}   0
		bold       {\*\*[^\*]+\*\*} {}         0         bold 0
	}]

	foreach {name marker color underline bold space} $linetypes {
		set pattern [string cat {^\s*} $marker {\s+.*$}]
		lappend syntax $name $pattern $color $underline $bold $space
	}

	foreach {name marker color underline bold space} $taskstates {
		set pattern [string cat $marker {\s+.*$}]
		lappend syntax $name $pattern $color $underline $bold $space
	}


	set linetype_markers [list]
	foreach {name marker color underline font space} $linetypes {
		lappend linetype_markers $marker
	}
	variable linetypepattern "(?:[join $linetype_markers {|}])"

	set taskstate_markers [list]
	foreach {name marker color underline font space} $taskstates {
		lappend taskstate_markers $marker
	}
	variable taskstatepattern "(?:[join $taskstate_markers {|}])"

	# this pattern MUST match mdedit::parse-line
	# (it is used there)
	variable linepattern {^(\s*)}
	append linepattern {(?:(} $linetypepattern {)\s)?}
	append linepattern {\s*(?:(} $taskstatepattern {)\s)?}
	append linepattern {\s*(.*)$}

	variable linetypemarker [dict create]
	foreach {name marker color underline bold space} $linetypes {
		dict set linetypemarker $name $marker
	}

	variable taskmarker [dict create]
	foreach {name marker color underline bold space} $taskstates {
		dict set taskmarker $name $marker
	}

	variable listmarker [dict get $linetypemarker list]
	variable quotemarker [dict get $linetypemarker quote]

	# map task marker -> next task state name
	variable next_task_marker [dict create]
	set last_task_marker ""
	foreach {name marker color underline bold space} $taskstates {
		dict set next_task_marker $last_task_marker $name
		set last_task_marker $marker
	}
	dict set next_task_marker $last_task_marker ""
}

# ---------------------------------------------------------------------------

# Fonts
namespace eval mdedit::fonts {
	set mono "Source Code Pro"
	set fam "Source Sans Pro"
	set P ::mdedit::fonts

	font create ${P}::code -family $mono -size 10
	font create ${P}::mono -family $mono -size 10
	font create ${P}::text -family $fam -size 10
	font create ${P}::bold -family $fam -size 10 -weight bold

	font create ${P}::h1   -family $fam -size 20 -weight bold
	font create ${P}::h2   -family $fam -size 18 -weight bold
	font create ${P}::h3   -family $fam -size 16 -weight bold
	font create ${P}::h4   -family $fam -size 14 -weight bold
	font create ${P}::h5   -family $fam -size 12 -weight bold
	font create ${P}::h6   -family $fam -size 10 -weight bold
}

# ---------------------------------------------------------------------------

proc mdedit::create {w} {
	set font ::mdedit::fonts::text
	text $w -font $font -undo 1

	# TODO: fix. currently it does remove all embedded windows
	#bind $w <Tab>        {mdedit::smart-tab %W; break}
	#bind $w <Shift-Tab>  {mdedit::dedent %W; break}
	bind $w <Return>     {mdedit::smart-return %W;           break}
	bind $w <KeyRelease> {mdedit::update-highlighting %W;    break}
	bind $w <Control-l>  {mdedit::update-highlighting %W 1;  break}
	bind $w <Control-u>  {mdedit::remove-highlighting %W;    break}
	bind $w <Configure>  {mdedit::on-resize %W}
	
	$w edit modified 0

	mdedit::update-tags $w

	# configure tabs to be of `tabwidth` width
	$w configure -tabs [expr {2 * [font measure $font 0]}]
	$w configure -tabstyle wordprocessor

	# configure main colors
	$w configure -foreground #000000
	$w configure -bg #ffffdd

	# other config
	$w configure  -padx 10 -pady 10
}

# ---------------------------------------------------------------------------

proc mdedit::on-resize {w} {
	set width [winfo width $w]
	foreach wrapper [$w window names] {
		$wrapper configure -width $width 
	}
}

# ---------------------------------------------------------------------------

proc mdedit::update-tags {w} {
	variable syntax

	foreach {name pattern color underline font space} $syntax {
		if {$color ne ""} {
			$w tag configure $name -foreground $color
		}
		if {$space != 0}  {
			$w tag configure $name -spacing1 $space
			$w tag configure $name -spacing3 $space
		}
		if {$underline} {
			$w tag configure $name -underline 1
		}
		if {$font ne ""} {
			set font ::mdedit::fonts::$font
			$w tag configure $name -font $font
		}
	}
}

# ---------------------------------------------------------------------------

proc mdedit::foreach-match {w pattern startvar endvar body} {
	upvar $startvar match_start
	upvar $endvar   match_end
	
	set match_start 1.0
	set match_end 1.0
	# we don't use the -all option for '$w search', so that 
	# the foreach-match user may modify the content 
	# of the range while iterating
	while {"" ne [set match_start \
		[$w search -regex -count match_len $pattern $match_end end]]
	} {
		set match_end [$w index "$match_start+$match_len c"]
		# use a mark. which is moved if the body should modify the range
		#$w mark set mdedit::foreach-match $match_end
		uplevel 1 $body
		#set match_end [$w index mdedit::foreach-match]
	}
}

# ---------------------------------------------------------------------------

proc mdedit::foreach-heading {w startvar endvar body} {
	uplevel 1 mdedit::foreach-match $w [list {^#+\s+.*$}] $startvar $endvar [list $body]
}

# ---------------------------------------------------------------------------

proc mdedit::iter-selected-lines {w startvar endvar body} {
	upvar $startvar linestart
	upvar $endvar   lineend

	if {[llength [$w tag ranges sel]] > 0} {
		set start "sel.first linestart"
		set end sel.last
	} else {
		set start "insert linestart" 
		set end   "insert lineend"
	}

	# iterate over each selected line
	set sellines [$w search -regex -all -count linelens -- {^.*$} $start $end]
	if {$sellines ne ""} {	
		foreach linestart $sellines linelen $linelens {
			set lineend [$w index "$linestart+$linelen c"]
			uplevel 1 $body
		}
	} else {
		set linestart insert
		set lineend insert
		uplevel 1 $body
	}
}

# ---------------------------------------------------------------------------

proc mdedit::build-line {indent linetype_marker taskstate_marker text} {
		set r "$indent"
		if {$linetype_marker ne ""} {
			append r "$linetype_marker "
		}
		if {$taskstate_marker ne ""} {
			append r "$taskstate_marker "
		}
		append r $text
		return $r
}

# ---------------------------------------------------------------------------

proc mdedit::parse-line {
	w
	start end 
	sep 
	indentvar linetypevar taskstatevar textvar
} {
	upvar 1 $indentvar indent
	upvar 1 $linetypevar linetype
	upvar 1 $taskstatevar taskstate
	upvar 1 $textvar text
	variable linepattern
	set line [$w get $start $end]
	regexp $linepattern $line -> indent linetype taskstate text
}

# ---------------------------------------------------------------------------

proc mdedit::set-line-type {w newtype} {
	variable linetypemarker
	$w edit separator

	mdedit::iter-selected-lines $w start end {
		if {[parse-line $w $start $end -> indent linetype taskstate text]} {
			# determine the marker symbol
			if {$newtype ne ""} {
				set newmarker [dict get $linetypemarker $newtype]
			} else {
				set newmarker ""
			}

			set newline [mdedit::build-line $indent $newmarker $taskstate $text]
			$w replace $start $end $newline
		}
	}

	mdedit::update-highlighting $w 1
}

# ---------------------------------------------------------------------------

proc mdedit::set-task-state {w newstate} {
	variable linepattern
	variable taskmarker
	$w edit separator

	mdedit::iter-selected-lines $w start end {
		if {[parse-line $w $start $end -> indent linetype taskstate text]} {
			# determine the marker symbol
			if {$newstate ne ""} {
				set newmarker [dict get $taskmarker $newstate]
			} else {
				set newmarker ""
			}

			set newline [mdedit::build-line $indent $linetype $newmarker $text]
			$w replace $start $end $newline
		}
	}

	mdedit::update-highlighting $w 1
}

# ---------------------------------------------------------------------------

proc mdedit::set-next-task-state {w} {
	variable next_task_marker

	set start "insert linestart"
	set end   "insert lineend"
	if {[mdedit::parse-line $w $start $end -> _ __ taskmarker ___]} {
		if {[dict exists $next_task_marker $taskmarker]} {
			set n [dict get $next_task_marker $taskmarker]
			mdedit::set-task-state $w $n
		}
	}
}

# ---------------------------------------------------------------------------


proc mdedit::dedent {w} {
	$w edit separator

	if {[llength [$w tag ranges sel]] > 0} {
		set start "sel.first linestart"
		set end sel.last
	} else {
		set start "insert linestart" 
		set end   "insert lineend"
	}

	set findings [$w search -regex -all -- {^\t} $start $end]
	foreach idx $findings {
		$w replace $idx "${idx} +1c" ""
	}

	mdedit::update-highlighting $w 1
}

# ---------------------------------------------------------------------------

proc mdedit::indent {w} \
{
	$w edit separator

	if {[llength [$w tag ranges sel]] > 0} {
		set start "sel.first linestart"
		set end sel.last
	} else {
		set start "insert linestart" 
		set end   "insert lineend"
	}

	set startpos [$w index $start]

	set txt [$w get $start $end]
	set lines [split $txt "\n"]
	set newlines [lmap l $lines {string cat "\t" $l}]
	set newtext [join $newlines "\n"]
	$w replace $start $end $newtext

	set endpos [$w index "$startpos + [string length $newtext] chars"]
	$w mark set insert $endpos
	$w tag add sel $startpos $endpos
	
	mdedit::update-highlighting $w 1
}

# ---------------------------------------------------------------------------

proc mdedit::smart-return {w} {
	variable listmarker
	variable quotemarker

	set start "insert linestart" 
	set end   "insert lineend"
	if {[parse-line $w $start $end -> indent linetype taskstate text]} {
		if {($linetype eq $listmarker) || ($linetype eq $quotemarker)} {
			set newline [build-line $indent $linetype $taskstate " "]
		} else {
			set newline ""
		}
		$w insert insert "\n$newline"
		$w see insert
		mdedit::update-highlighting $w 0
	}
}

# ---------------------------------------------------------------------------

proc mdedit::smart-tab {w} {
	if {[llength [$w tag ranges sel]] > 0} {
		mdedit::indent $w
	} else {
		$w insert insert "\t"
	}
}

# ---------------------------------------------------------------------------

proc mdedit::remove-highlighting {w} {
	variable syntax

	# remove all markdown highlighting
	foreach {name pattern color underline font space} $syntax {
		$w tag remove $name 1.0 end
	}
	
	# code-blocks stay as they are (else we get into a nightmare...)
	# use get-text to retrieve text
}

# ---------------------------------------------------------------------------

proc mdedit::update-highlighting {w {full 0}} {
	variable syntax

	# While typing limit the scope of the search to the current line
	# (for performance reasons)
	if {!$full} {
		set start "insert linestart"
		set end   "insert lineend"
	# yet, after loading the file do a full search over the doc for the pattern
	} else {
		set start "1.0"
		set end   "end"	
	}

	# upon full rerendering: first remove all tags
	if {$full} {
		mdedit::remove-highlighting $w
	}
	
	# highlight code blocks
	# also hide them so the following element highlighting ignored text in codeblocks
	if {$full} {
		mdedit::highlight-codeblocks $w
	}

	# highlight images
	mdedit::highlight-images $w $start $end	

	# highlight each syntax element in the document/line
	foreach {name pattern color underline font space} $syntax {
		mdedit::highlight-pattern $w $name $pattern $start $end
	}
	
	# unhide codeblocks
	$w tag configure codeblock -elide 0
}

# ---------------------------------------------------------------------------
# searches for a pattern and applies the given tag if it is found.

proc mdedit::highlight-pattern {w tag pattern start end} {
	
	# remove all tags from range
	$w tag remove $tag $start $end

	# perform the actual search/tag adding
	set matches [$w search -regexp -all -count matchlens $pattern $start $end]
	if {[llength $matches] > 0} {
		foreach index $matches len $matchlens {
			$w tag add $tag $index "$index+${len}chars"
		}
	}
}

# ---------------------------------------------------------------------------

proc mdedit::highlight-images {w start end} {
	set pat $::mdedit::image::pattern
	
	set m_end $start
	while {"" ne [set m_start \
			[$w search -regexp -nolinestop -count len $pat $m_end $end]]
	} {
		set m_end [$w index "$m_start+${len}chars lineend"]
		
		# create a text wrapper for the codeblock
		set widgetproc mdedit::image::create
		mdedit::textwrapper::create $w $m_start $m_end $widgetproc
	}
}

# ---------------------------------------------------------------------------

proc mdedit::highlight-codeblocks {w} {
	set pat {```.*?```$}
	
	# restarts always from the top
	# which is okay, because textwrapper::create removes the 
	# codeblock found by "$w search"
	while {"" ne [set blockstart \
			[$w search -regexp -nolinestop -count len $pat 1.0 end]]
	} {
		set blockend [$w index "$blockstart+${len}chars lineend"]
		
		# create a text wrapper for the codeblock
		set widgetproc mdedit::codeblock::create
		mdedit::textwrapper::create $w $blockstart $blockend $widgetproc
	}
}

# ---------------------------------------------------------------------------

proc mdedit::set-text {w text} { 
	$w configure -background #ffffdd
	$w configure -state normal
	
	$w edit reset
	$w replace 1.0 end $text
	mdedit::update-highlighting $w 1
	
	# show cursor in view
	$w mark set insert 1.0
	$w see insert
	focus $w
}

# ---------------------------------------------------------------------------

proc mdedit::get-text {w {start 1.0} {end end}} {	
	set r [list]
	set dump [$w dump -text -image -window $start $end]
	foreach {type content index} $dump {
		switch -exact $type {
			text {
				lappend r $content
			}
			window {	
				set window $content
				lappend r [mdedit::textwrapper::get-text $window]
			}
		}
	}
	return [join $r ""]
}

# ---------------------------------------------------------------------------

# replace selection with text or insert text at cursor
proc mdedit::paste {w text} {
	if {[$w tag nextrange sel 1.0] eq ""} {
		$w insert insert $text
	} else {
		$w replace sel.first sel.last $text
	}
	mdedit::update-highlighting $w 1
}

# ---------------------------------------------------------------------------

# see index and focus editor a little different to 'text see'
proc mdedit::goto {w index} {
	$w tag remove sel 1.0 end
	$w mark set insert $index
	$w see insert
	focus $w
}

# ---------------------------------------------------------------------------

proc mdedit::select {w a b} {
	$w tag remove sel 1.0 end
	$w mark set insert $b
	$w tag add sel $a $b
	$w see insert
	focus $w
}

# ---------------------------------------------------------------------------

proc mdedit::find {w needle start end} {	
	set needlelen [string length $needle]
	set numlines [$w count -lines $start $end]
	for {set lineno 0} {$lineno < $numlines} {incr lineno} {

		# get a dump of the current line
		if {$lineno == 0} {
			set linestart [$w index $start]
		} else {
			set linestart [$w index "$start + $lineno lines linestart"]
		}
		set lineend   [$w index "$start + $lineno lines lineend"]
		set dump [$w dump -text -image -window $linestart $lineend]

		# search in each part of the line
		foreach {type content index} $dump {
			switch -exact $type {

				text {
					set first [string first $needle $content]
					if {$first > -1} {
						set a [$w index "$index + $first chars"]
						set b [$w index "$a + $needlelen chars"]
						mdedit::select $w $a $b
						return 1
					}
				}

				window {	
					set window $content
					set content [mdedit::textwrapper::get-text $window]
					set first [string first $needle $content]
					if {$first > -1} {
						set b [$w index "$index + 1i"]
						mdedit::select $w $index $b
						return 1
					}
				}

			}
		}
	}
	return 0
}

# ---------------------------------------------------------------------------

proc mdedit::find-next {w needle} {
	mdedit::find $w $needle insert end
}

# ---------------------------------------------------------------------------
# Text as Window Container
# ---------------------------------------------------------------------------

namespace eval mdedit::textwrapper {
	variable counter [dict create]
	variable wrappertext [dict create]
}

# ---------------------------------------------------------------------------

proc mdedit::textwrapper::create {w start end widgetproc} {
	variable counter
	variable wrappertext

	# create unique id for wrapper
	dict incr counter $w
	set cnt [dict get $counter $w]

	# widget aliases
	set wrapper $w.codeblock-image-wrapper-$cnt
	
	# root frame -- created here to have consistend behavior 
	# across different wrappers
	frame $wrapper -bd 1 -bg "#000"
	$wrapper configure -cursor hand2

	# get the text of the region
	set text [$w get $start $end]

	# delete the original codeblock
	$w delete $start $end

	# store the text wrapped
	set-text $wrapper $text

	# forward the rest of the wrapper to the edit_namespace
	$widgetproc $wrapper $text

	# insert wrapper in text control 
	$w window create $start -window $wrapper

	return $wrapper
}

# ---------------------------------------------------------------------------

proc mdedit::textwrapper::get-text {wrapper} {
	variable wrappertext
	dict get $wrappertext $wrapper
}

# ---------------------------------------------------------------------------

proc mdedit::textwrapper::set-text {wrapper text} {
	variable wrappertext
	dict set wrappertext $wrapper $text
}

# ---------------------------------------------------------------------------
# Image Highlighting
# ---------------------------------------------------------------------------

namespace eval mdedit::image {
	variable image_counter 0
	variable pattern {!\[(.*?)\]\((.*?)\)}
}

namespace eval mdedit::image::images {}

# ---------------------------------------------------------------------------

proc mdedit::image::create {wrapper text} {
	# widget names
	set I $wrapper.img
	set A $wrapper.alt
	set E $wrapper.err

	# commands
	set editcmd [list ::mdedit::image::edit $wrapper]
	
	# the image widget
	label $I
	bind $I <Button-1> $editcmd

	# alt text
	label $A
	pack $A -fill x
	bind $A <Button-1> $editcmd
	
	# Error Message
	label $E -foreground "#a00" -font ::mdedit::fonts::code
	$E configure -justify left -anchor nw
	bind $E <Button-1> $editcmd

	# namespace local "apply" proc
	apply $wrapper $text
}

# ---------------------------------------------------------------------------

proc mdedit::image::apply {wrapper text} {
	variable image_counter
	variable pattern

	# widget names
	set I $wrapper.img
	set A $wrapper.alt
	set E $wrapper.err

	mdedit::textwrapper::set-text $wrapper $text

	pack forget $A
	pack forget $I
	pack forget $E

	if {[regexp $pattern $text -> alt filename]} {
		incr image_counter
		set oldimg [$I cget -image]
		set newimg ::mdedit::image::images::img$image_counter

		# create image and show in the form
		if {![catch {image create photo $newimg -file $filename}]} {
			$I configure -image $newimg
			pack $I -fill both -expand 1
			if {$oldimg ne ""} {
				image delete $oldimg
			}
			if {$alt ne ""} {
				$A configure -text $alt
				pack $A -fill both -expand 1
			}
		} else {
			# error loading image: show in form
			$E configure -text "error reading image '$filename'"
			pack $E -fill both -expand 1
		}
	} else {
		# error parsing markdown: show in form
		$E configure -text "error parsing image '$image'"
		pack $E -fill both -expand 1
	}
}

# ---------------------------------------------------------------------------

proc mdedit::image::edit {wrapper} {
	variable pattern

	# widget shorthands
	set D $wrapper.dlg      ;# Dialog
	set A $wrapper.dlg.alt  ;# Alt Text
	set F $wrapper.dlg.fn   ;# Filename

	# dialog actions
	set okcmd [list \
			::mdedit::image::edit-confirm $wrapper $D]
	set cancelcmd [list destroy $D]

	# dialog state
	set text [mdedit::textwrapper::get-text $wrapper]
	if {![regexp $pattern $text -> alt filename]} {
		set alt ""
		set filename ""
	}

	# Create the dialog
	toplevel $D
	grid rowconfigure $D 1 -weight 1
	grid columnconfigure $D 1 -weight 1
	grid columnconfigure $D 4 -weight 1
	wm attributes $D -toolwindow 1 -topmost 1
	wm title $D "Edit Codeblock"
	bind $D <Return> "$okcmd; destroy $D"
	bind $D <Escape> "destroy $D"

	# Alt Text
	set lbl [ttk::label $D.l1 -text "Alt Text:" -justify left -anchor nw]
	grid $lbl -row 0 -column 0 -sticky nswe
	ttk::entry $A 
	grid $A -row 0 -column 1 -columnspan 4 -sticky nswe
	$A insert 1 $alt

	# Filename
	set lbl [ttk::label $D.l2 -text "Filename:" -justify left -anchor nw]
	grid $lbl -row 1 -column 0 -sticky nswe
	ttk::entry $F 
	grid $F -row 1 -column 1 -columnspan 4 -sticky nswe
	$F insert 1 $filename
	
	# OK/Cancel Button
	set btnOk $wrapper.dlg.ok
	button $btnOk -text Ok -command "$okcmd; destroy $D" -default active -width 10
	grid $btnOk -column 2 -row 2 -padx 5 -pady 5
	set btnCancel $wrapper.dlg.cancel
	button $btnCancel -text Cancel -command "destroy $D" -width 10
	grid $btnCancel -column 3 -row 2 -padx 5 -pady 5

	# Highlight and wait for the dialog
	focus $F
	grab $D
	tkwait window $D
}

# ---------------------------------------------------------------------------

proc mdedit::image::edit-confirm {wrapper dlg} {
	# widget shorthands
	set D $dlg      ;# Dialog
	set A $dlg.alt  ;# Alt Text
	set F $dlg.fn   ;# Filename
	set alt [string trim [$A get]]
	set filename [$F get]
	set text "!\[$alt\]($filename)"
	if {[mdedit::textwrapper::get-text $wrapper] ne $text} {
		apply $wrapper $text
	}
	destroy $dlg
}

# ---------------------------------------------------------------------------
# Codeblock Highlighting
# ---------------------------------------------------------------------------

namespace eval mdedit::codeblock {}

# ---------------------------------------------------------------------------

proc mdedit::codeblock::create {wrapper text} {
	# widget names
	set H $wrapper.h
	set T $wrapper.content
	set I $wrapper.img
	set E $wrapper.err

	# commands
	set editcmd [list ::mdedit::codeblock::edit $wrapper]

	# header
	label $H -justify right -font ::mdedit::fonts::code
	pack $H -fill x
	bind $H <Button-1> $editcmd
	
	# the image widget
	label $I
	bind $I <Button-1> $editcmd

	text $T -font ::mdedit::fonts::code
	bind $T <Button-1> $editcmd
	$T configure -state disabled
	$T configure -cursor hand2
	
	# Error Message
	label $E -foreground "#a00" -font ::mdedit::fonts::code
	$E configure -justify left -anchor nw
	bind $E <Button-1> $editcmd

	# namespace local "apply" proc
	apply $wrapper $text
}

# ---------------------------------------------------------------------------

proc mdedit::codeblock::parse {text blocktypevar contentvar} {
	upvar 1 $blocktypevar blocktype
	upvar 1 $contentvar content

	set lines [split $text "\n"]

	if {[regexp -lineanchor -linestop {```\s*(.*)\s*$} $text -> blocktype]} {
		set blocktype [string trim $blocktype]
		set contentlines [lrange $lines 1 end-1]
		set content [join $contentlines "\n"]
		return 1
	} else {
		return 0
	}
}

# ---------------------------------------------------------------------------

proc mdedit::codeblock::apply {wrapper text} {
	# widget names
	set H $wrapper.h
	set T $wrapper.content
	set I $wrapper.img
	set E $wrapper.err

	mdedit::textwrapper::set-text $wrapper $text

	set lines [split $text "\n"]

	if {[parse $text blocktype content]} {
		set plugin ::mdedit::codeblock2img::$blocktype

		$H configure -text $blocktype

		# show either the block's content or an image of the result
		# first: unpack both widgets
		pack forget $T
		pack forget $I
		pack forget $E

		# is there a plugin for the blocktype which does generate an image?
		if {[namespace exists $plugin]} {
			if {[${plugin}::parse $content result]} {
				$I configure -image $result
				pack $I -fill both -expand 1
			} else {
				# had error in script
				$E configure -text $result
				pack $E -fill both -expand 1
			}

		# else: show the blocks content
		} else {
			$T configure -state normal
			$T replace 1.0 end $content
			$T configure -height [$T count -lines 1.0 end]
			$T configure -state disabled
			pack $T -fill both -expand 1
		}
	}
}

# ---------------------------------------------------------------------------

proc mdedit::codeblock::edit {wrapper} {

	# widget shorthands
	set D $wrapper.dlg      ;# Dialog
	set T $wrapper.dlg.t    ;# Text Editor
	set H $wrapper.dlg.h    ;# Header/Block Type

	# dialog actions
	set okcmd [list \
			::mdedit::codeblock::edit-confirm $wrapper $D]
	set cancelcmd [list destroy $D]

	# dialog state
	set text [mdedit::textwrapper::get-text $wrapper]
	if {![parse $text blocktype content]} {
		set blocktype ""
		set content ""
	}

	# Create the dialog
	toplevel $D
	grid rowconfigure $D 1 -weight 1
	grid columnconfigure $D 1 -weight 1
	grid columnconfigure $D 4 -weight 1
	wm attributes $D -toolwindow 1 -topmost 1
	wm title $D "Edit Codeblock"
	bind $D <Return> "$okcmd; destroy $D"
	bind $D <Escape> "destroy $D"

	# Blocktype Edit
	ttk::entry $H 
	grid $H -row 0 -column 1 -columnspan 4 -sticky nswe
	$H insert 1 $blocktype
	
	# Text editor
	text $T
	grid $T -sticky nsew -columnspan 4 -column 1 -row 1
	bind $T <Return> {%W insert insert "\n"; break}
	$T insert 1.0 $content
	
	# OK/Cancel Button
	set btnOk $wrapper.dlg.ok
	button $btnOk -text Ok -command "$okcmd; destroy $D" -default active -width 10
	grid $btnOk -column 2 -row 2 -padx 5 -pady 5
	set btnCancel $wrapper.dlg.cancel
	button $btnCancel -text Cancel -command "destroy $D" -width 10
	grid $btnCancel -column 3 -row 2 -padx 5 -pady 5

	# Highlight and wait for the dialog
	focus $T
	grab $D
	tkwait window $D
}

# ---------------------------------------------------------------------------

proc mdedit::codeblock::edit-confirm {wrapper dlg} {
	set T $dlg.t
	set H $dlg.h
	set blocktype [string trim [$H get]]
	set content [$T get 1.0 end]
	set text "```$blocktype\n$content\n```"
	if {[mdedit::textwrapper::get-text $wrapper] ne $text} {
		apply $wrapper $text
	}
	destroy $dlg
}

# ===========================================================================
# Codeblock to image Plugins
# ===========================================================================

namespace eval mdedit::codeblock2img {
	variable image_counter 0
}

# store the images created by run-tool
namespace eval mdedit::codeblock2img::images {}

# ---------------------------------------------------------------------------

# execute args using exec and read the generated png file
# use %f to use a randomly created png file name in the command
# returns an tk image name
proc mdedit::codeblock2img::run-tool {content cmd resvar} { 
	variable image_counter
	upvar 1 $resvar result

	incr image_counter

	close [file tempfile tmpfile]
	file delete -force $tmpfile
	set tmpfile ${tmpfile}.png
	
	# replace %f with tmpfile
	set cmd [lmap e $cmd {string map [list %f $tmpfile] $e}]

	# exec command and catch errors
	if {![catch {exec {*}$cmd << $content} _ errinfo]} {
		set result mdedit::codeblock2img::images::img$image_counter
		image create photo $result -file $tmpfile
		file delete -force $tmpfile
		return 1
	} else {
		set result [dict get $errinfo -errorinfo]
		return 0
	}
}

# ---------------------------------------------------------------------------
# Gnuplot Plugin
# ---------------------------------------------------------------------------

namespace eval mdedit::codeblock2img::gnuplot {
	variable cache [dict create]
}

# ---------------------------------------------------------------------------

proc mdedit::codeblock2img::gnuplot::parse {content resultvar} {
	upvar 1 $resultvar result
	variable cache

	if {[dict exists $cache $content]} {
		return [dict get $cache $content]

	# not in cache. create image	
	} else {
		set cmd [list {c:\\Program Files\gnuplot\\bin\\gnuplot.exe}]
		lappend cmd -e "set term pngcairo" -e "set output '%f'" -

		# 'result' is set by $genimg. no need to modify/use it
		return [::mdedit::codeblock2img::run-tool $content $cmd result]
	}
}
