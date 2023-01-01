# ===========================================================================
# Globals 
# ===========================================================================

package require Tk

encoding system utf-8

source lib/Toolbar.tcl
source lib/kanban.tcl
source lib/mdedit.tcl
source lib/LoadSave.tcl
source lib/appicons.tcl

# ===========================================================================
# Global Objects
# ===========================================================================

# Create the Object
set loadsave [LoadSave new "Engineers Zettelkasten Edit"]

# Add a Filetype
$loadsave add-filetype "Markdown Files" *.md *.txt
$loadsave add-filetype "All Files" *.*

set kanban_visible 1

# Script root directory
set scriptdir [file dirname [file normalize [info script]]]
set paste_image_tool $::scriptdir/tools/save-clipboard-image.exe

# find-next needle
set needle ""
set needle_history [list]

# ===========================================================================
# App Events
# ===========================================================================

proc on-apply-settings {} {
	mdedit::update-tags $::T
}

# ===========================================================================
# App Commands
# ===========================================================================

proc cmd-new {} {
	set oldcontent [mdedit::get-text $::T]
	if {[$::loadsave new $oldcontent]} {
		mdedit::set-text $::T ""
	}
}

# ---------------------------------------------------------------------------

proc cmd-open {{filename ""}} {
	set oldcontent [mdedit::get-text $::T]
	if {[$::loadsave open $oldcontent content $filename]} {

		# change directory into file directory to
		# allow relative links/images
		set dirname [file dirname $filename]
		cd $dirname
		mdedit::set-text $::T $content
	}
}

# ---------------------------------------------------------------------------

proc cmd-save {} {
	$::loadsave save [mdedit::get-text $::T]
}

# ---------------------------------------------------------------------------

proc cmd-save-as {} {
	$::loadsave save-as [mdedit::get-text $::T]
}

# ---------------------------------------------------------------------------

proc cmd-cut {} {
	set text [mdedit::get-text $::T sel.first sel.last]
	$::T delete sel.first sel.last
	clipboard clear
	clipboard append $text
}

# ---------------------------------------------------------------------------

proc cmd-copy {} {
	set text [mdedit::get-text $::T sel.first sel.last]
	clipboard clear
	clipboard append $text
}

# ---------------------------------------------------------------------------

proc cmd-paste {} {
	# TCL/TK does sadly currently not support pasting
	# image data from clipboard.
	# our workaround is to have a small binary which uses
	# the win32 api to store image data in clipboard as a PNG-File
	# If no image data is in the clipboard we try to access text data
	set now [clock seconds]
	set date [clock format $now -format %Y%m%d%H%M%S]
	set fn $date.png

	# is image data in clipboard
	if {![catch {exec $::paste_image_tool $fn}]} {
		mdedit::paste $::T "!\[\]($fn)"
	
	# text data in clipboard
	} elseif {![catch {clipboard get} content]} {
		mdedit::paste $::T $content
	}
}
# ---------------------------------------------------------------------------

proc cmd-task-next-state {} {
	mdedit::set-next-task-state $::T
}

# ---------------------------------------------------------------------------

proc cmd-task-task {} {
	mdedit::set-task-state $::T task
}

# ---------------------------------------------------------------------------

proc cmd-task-done {} {
	mdedit::set-task-state $::T done
}

# ---------------------------------------------------------------------------

proc cmd-task-wip {} {
	mdedit::set-task-state $::T wip
}

# ---------------------------------------------------------------------------

proc cmd-task-wait {} {
	mdedit::set-task-state $::T wait
}

# ---------------------------------------------------------------------------

proc cmd-task-none {} {
	mdedit::set-task-state $::T ""
}

# ---------------------------------------------------------------------------

proc cmd-mark-list {} {
	mdedit::set-line-type $::T list
}

# ---------------------------------------------------------------------------

proc cmd-mark-quote {} {
	mdedit::set-line-type $::T quote
}

# ---------------------------------------------------------------------------

proc cmd-mark-none {} {
	mdedit::set-line-type $::T "" 
}

# ---------------------------------------------------------------------------

proc cmd-mark-heading1 {} {
	mdedit::set-line-type $::T h1
}

# ---------------------------------------------------------------------------

proc cmd-mark-heading2 {} {
	mdedit::set-line-type $::T h2
}

# ---------------------------------------------------------------------------

proc cmd-mark-heading3 {} {
	mdedit::set-line-type $::T h3
}

# ---------------------------------------------------------------------------

proc cmd-mark-heading4 {} {
	mdedit::set-line-type $::T h4
}

# ---------------------------------------------------------------------------

proc cmd-mark-heading5 {} {
	mdedit::set-line-type $::T h5
}

# ---------------------------------------------------------------------------

proc cmd-mark-heading6 {} {
	mdedit::set-line-type $::T h6
}

# ---------------------------------------------------------------------------

proc cmd-indent {} {
	mdedit::indent $::T
}

# ---------------------------------------------------------------------------

proc cmd-dedent {} {
	mdedit::dedent $::T
}

# ---------------------------------------------------------------------------

proc cmd-show-hide-kanban {} {
	if {$::kanban_visible} {
		.split insert 0 $::K
	} else {
		.split forget $::K
	}
}

# ---------------------------------------------------------------------------

proc cmd-show-find {} {
	pack $::findtb -fill x -after $::edittb
	focus $::findcombo
}

# ---------------------------------------------------------------------------

proc cmd-hide-find {} {
	pack forget $::findtb
	focus $::T
}

# ---------------------------------------------------------------------------

proc cmd-find-next {} {
	if {[mdedit::find-next $::T $::needle]} {
		if {$::needle ni $::needle_history} {
			lappend ::needle_history $::needle
			$::findcombo configure -values $::needle_history
		}
		# focus $::findcombo
	}
}

# ===========================================================================
# Map Markdown to Kanban
# ===========================================================================

proc update-card {K card newtext newcol index} {
	# add/set text of card
	set oldtext [kanban::itemcget $K $card -text]
	if {$newtext ne $oldtext} {
		kanban::itemconfigure $K $card -text $newtext
	}
	
	# move card to correct col
	set oldcol [kanban::cardcol $K $card]
	if {$oldcol != $newcol} {
		kanban::move $K $card $newcol
	}

	kanban::bind $K $card <Button-1> [list mdedit::goto $::T $index]
	
	if {[kanban::exists $K $card]} {
		#kanban::biind
	}
}

# ---------------------------------------------------------------------------

proc header-to-kanban {} {
	set K $::K
	set T $::T
	set h_num 0
	
	set cards  [kanban::cards $K]
	set numcards [llength $cards]
	
	mdedit::foreach-heading $T h_start h_end {
		if {
			   [mdedit::parse-line $T $h_start $h_end -> _ h_lvl todotag h_text]
			&& $h_lvl eq "##"
			&& [dict exists $::kanbancol $todotag]
		} {

			if {[llength $cards] <= $h_num} {
				set card [kanban::add $K 1 -text $h_text]
				kanban::itemconfigure $K $card -cursor hand2
				lappend cards $card
			} else {
				set card [lindex $cards $h_num]
			}
			
			set newcol [dict get $::kanbancol $todotag]
			update-card $K $card $h_text $newcol $h_start
			
			incr h_num
		}
		
	}
	
	for {set i $h_num} {$i < [llength $cards]} {incr i} {
		set card [lindex $cards $i]
		kanban::delete $K $card
	}
}

# ===========================================================================
# User Interface
# ===========================================================================

# Widget Shortcuts
set K .split.kanban
set T .split.lower.doc
set findtb .split.lower.find-tb
set edittb .split.lower.edit-tb

# ---------------------------------------------------------------------------

#  Window Title
wm title . "Engineers Zettelkasten Edit"

# ---------------------------------------------------------------------------

# Application main Toolbar
set tb [Toolbar new .main-tb]
$tb add "New" file-new-24x24 cmd-new
$tb add "Open" file-open-24x24 cmd-open
$tb add "Save" file-save-24x24 cmd-save
$tb add "Save As" file-save-as-24x24 cmd-save-as
$tb add-sep
$tb add "Cut" cmd-cut-24x24 cmd-cut
$tb add "Cut" cmd-copy-24x24 cmd-copy
$tb add "Paste" cmd-paste-24x24 cmd-paste
$tb add-sep
$tb add-check "Show Kanban" {} cmd-show-hide-kanban ::kanban_visible
pack .main-tb -fill x

# ---------------------------------------------------------------------------

# Vertical Split between Kanban and Editor
ttk::panedwindow .split -orient vertical ;# horizontal
pack .split -expand 1 -fill both

# ---------------------------------------------------------------------------

# kanban board
set K .split.kanban
kanban::create $K -readonly 1
.split add $K

# add colums
set kanbancol [dict create]
dict set kanbancol ☐ [kanban::add-col $K -label Todo]
dict set kanbancol ► [kanban::add-col $K -label WIP]
dict set kanbancol W [kanban::add-col $K -label Wait]
dict set kanbancol ✓ [kanban::add-col $K -label Done]

# ---------------------------------------------------------------------------

# Lower container
frame .split.lower
.split add .split.lower

# ---------------------------------------------------------------------------

# Edit Toolbar
set tb [Toolbar new $edittb]
$tb add "" cmd-dedent-16x16 cmd-dedent
$tb add "" cmd-indent-16x16 cmd-indent
$tb add-sep
$tb add "Task" status-todo-16x16 cmd-task-task
$tb add "Done" status-done-16x16 cmd-task-done
$tb add "WIP " cmd-play-16x16 cmd-task-wip
$tb add "Waiting" cmd-pause-16x16 cmd-task-wait
$tb add "No Task" cmd-format-16x16 cmd-task-none
$tb add-sep
$tb add "Title" cmd-heading1-16x16 cmd-mark-heading1
$tb add "" cmd-heading2-16x16 cmd-mark-heading2
$tb add "" cmd-heading3-16x16 cmd-mark-heading3
$tb add "H4" {} cmd-mark-heading4
$tb add "H5" {} cmd-mark-heading5
$tb add "H6" {} cmd-mark-heading6
$tb add "List" cmd-list-16x16 cmd-mark-list
$tb add "Quote" {} cmd-mark-quote
$tb add "Clear" cmd-format-16x16 cmd-mark-none
pack $edittb -fill x

# ---------------------------------------------------------------------------

# Find Toolbar
set tb [Toolbar new $findtb]
$tb add "×" {} cmd-hide-find
set findcombo [$tb add-combo "Search for:" ::needle $::needle_history]
$tb add "Find Next" {} cmd-find-next
# start with hidden find toolbar
#pack .split.lower.find-tb -fill x
bind $::findcombo <Return> cmd-find-next
bind $::findcombo <Escape> cmd-hide-find

# ---------------------------------------------------------------------------

# scrollbar
ttk::scrollbar .split.lower.ysb -orient vertical -command [list $T yview]
pack .split.lower.ysb -fill y -side right

# ---------------------------------------------------------------------------

# Todo-List Editor
mdedit::create $T 
$T configure -yscrollcommand [list .split.lower.ysb set]
pack $T -fill both -expand 1
bind $T <Control-minus>   {cmd-mark-list; break}
bind $T <Control-d>       {cmd-task-next-state; break}
bind $T <Control-Key-1>   {cmd-mark-heading1; break}
bind $T <Control-Key-2>   {cmd-mark-heading2; break}
bind $T <Control-Key-3>   {cmd-mark-heading3; break}
bind $T <Control-Key-4>   {cmd-mark-heading4; break}
bind $T <Control-Key-5>   {cmd-mark-heading5; break}
bind $T <Control-Key-6>   {cmd-mark-heading6; break}
bind $T <Control-0>       {cmd-mark-none; break}
bind $T <F5>              {cmd-insert-date; break}
bind $T <Control-Return>  {cmd-smart-newline; break}
bind $T <Control-x>       {cmd-cut; break}
bind $T <Control-c>       {cmd-copy; break}
bind $T <Control-v>       {cmd-paste; break}


bind $T <<Modified>> {
	if {[%W edit modified]} {
		%W edit modified 0
		header-to-kanban
		$::loadsave modified 1
	}
}

# ===========================================================================
# Global Bindings
# ===========================================================================

bind . <Control-q> {destroy .}
bind . <Control-n> cmd-new
bind . <Control-o> cmd-open
bind . <Control-s> cmd-save
bind . <Control-Shift-s> cmd-save-as
bind . <Control-f> cmd-show-find

# ===========================================================================
# App Startup
# ===========================================================================

on-apply-settings

if {$argc > 0} {
	cmd-open [lindex $argv 0]
}

focus $T
wm deiconify .
#wm state . zoomed



