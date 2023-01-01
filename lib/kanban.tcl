# ===========================================================================
# Kanban Board Component
# ===========================================================================

namespace eval kanban {
	variable numcols [dict create]
	variable numcards [dict create]
	variable dragged_item [dict create]
	variable dragged_highlight [dict create]
	variable dragged_highlight_bg [dict create]
	
	variable card_to_column [dict create]
	
	variable optdefaults [dict create]
	dict set optdefaults -background "#fff"
	dict set optdefaults -readonly 0
	variable optkeys [dict keys $optdefaults]

	variable coloptdefaults [dict create]
	dict set coloptdefaults -label ""
	variable coloptkeys [dict keys $coloptdefaults]

	variable itemoptdefaults [dict create]
	dict set itemoptdefaults -text ""
	variable itemoptkeys [dict keys $itemoptdefaults]
	
	# options
	variable opt_readonly [dict create]; # support drag/drop etc.
}

# ---------------------------------------------------------------------------

proc kanban::create {w args} {
	variable optdefaults
	variable numcols
	variable card_to_column 
	
	dict set numcols $w 0
	
	dict set card_to_column $w [dict create]
	
	frame $w
	grid rowconfigure $w 1 -weight 1
	
	uplevel 1 kanban::configure $w $optdefaults
	uplevel 1 kanban::configure $w $args

	return $w
}

# ---------------------------------------------------------------------------

proc kanban::configure {w args} {
	variable optkeys
	
	foreach {arg val} $args {
		switch [tcl::prefix match -exact $optkeys $arg] {
			-background  { 
				$w configure -bg $val 
			}
			-readonly { 
				variable opt_readonly
				dict set opt_readonly $w [expr {$val ? 1 : 0 }]
			}
		}
	}
}

# ---------------------------------------------------------------------------

proc kanban::add-col {w args} {
	variable coloptdefaults
	variable numcols
	
	dict incr numcols $w
	set col [dict get $numcols $w]
	
	# widget names and grid positions
	set lbl $w.label-$col
	set cnv [kanban::containerwindow $w $col]
	set cnvpos [expr {2*$col}]
	set scroll $w.scroll-$col
	set scrollpos [expr {$cnvpos+1}]
	set content $cnv.content
	
	# style
	set bg [$w cget -bg]
	
	# heading
	ttk::label $lbl -justify center
	grid $lbl -column $cnvpos -row 0 -sticky nsew -columnspan 2

	# canvas as scrolled frame
	canvas $cnv -bg $bg -bd 0
	$cnv configure -yscrollcommand "$scroll set"
	$cnv configure -scrollregion [$cnv bbox all]
	grid $cnv -column $cnvpos -row 1 -sticky nsew
	
	# scrollbar
	ttk::scrollbar $scroll -orient vertical -command [list $cnv yview]
	grid $scroll -column $scrollpos -row 1 -sticky nsew
	
	# the frame which holds the cards
	frame $content -bg $bg
	::bind $content <Configure> "$cnv configure -scrollregion [$cnv bbox all]"
	$cnv create window 0 0 -window $content -anchor nw
	::bind $cnv <Configure> {%W itemconfigure 1 -width %w}
	
	# ensure grid is properly configured using the new column
	grid columnconfigure $w $cnvpos -weight 1
	
	# apply arguments
	uplevel 1 kanban::configure-col $w $col $coloptdefaults
	uplevel 1 kanban::configure-col $w $col $args

	return $col
}

# ---------------------------------------------------------------------------

proc kanban::configure-col {w col args} {
	variable coloptkeys
	set lbl $w.label-$col
	foreach {arg val} $args {
		switch [tcl::prefix match -exact $coloptkeys $arg] {
			-label  { $lbl configure -text $val}
		}
	}
}

# ---------------------------------------------------------------------------

proc kanban::add {w col args} {
	variable numcards
	variable itemoptdefaults

	# generate card unique id
	dict incr numcards $w
	set card [dict get $numcards $w]
	
	# create the window
	kanban::add-card-to-col $w $card $col

	# apply arguments
	uplevel 1 kanban::itemconfigure $w $card $itemoptdefaults
	uplevel 1 kanban::itemconfigure $w $card $args

	# return element id
	return  $card
}
# ---------------------------------------------------------------------------

proc kanban::add-card-to-col {w card col {before ""}} {
	variable card_to_column
	variable opt_readonly

	# store column of card
	dict set card_to_column $w $card $col

	set cnv [kanban::containerwindow $w $col]
	set cw [kanban::cardwindow $w $card]
	
	ttk::label $cw -background "#aaffee" -padding 5
	if {$before ne ""} {
		pack $cw -before $before -fill x -padx 5 -pady 5
	} else {
		pack $cw -fill x -padx 5 -pady 5
	}
	
	# is kanban board interactive or readonly
	if {![dict get $opt_readonly $w]} {
		::bind $cw <ButtonPress-1> [list kanban::start-drag $w $card ]
		::bind $cw <Motion> [list kanban::while-drag $w $card %X %Y]
		::bind $cw <ButtonRelease-1> [list kanban::stop-drag $w $card %X %Y]
	}
	
	return $cw
}

# ---------------------------------------------------------------------------

proc kanban::start-drag {w card} {
	variable dragged_item
	dict set dragged_item $w $card
	$w configure -cursor hand2
}

# ---------------------------------------------------------------------------

proc kanban::while-drag {w card rootX rootY} {
	variable dragged_item
	
		#	&& $rootX > 0 && $rootX < [winfo width $w]
		#	&& $rootY > 0 && $rootY < [winfo height $w]
	if {
		[dict exists $dragged_item $w]	
	} {
		
		# find a label under the cursor
		set new ""
		set tmp [winfo containing $rootX $rootY]
		if {$tmp ne "" && [winfo class $tmp] eq "TLabel"} {
			set new $tmp
		}
		
		kanban::set-drag-highlight $w $new
	}
}

# ---------------------------------------------------------------------------

proc kanban::stop-drag {w card rootX rootY} {
	variable dragged_item
	variable card_to_column
	
	set x [expr {$rootX - [winfo rootx $w]}]
	set y [expr {$rootY - [winfo rooty $w]}]
	
	if {[dict exists $dragged_item $w]} {
		set col [kanban::cardcol $w $card]

		set newcol [kanban::col-for-pos $w $x $y]		
		set before [kanban::set-drag-highlight $w ""]
		
		if {$newcol > -1 && $newcol != $col} {
			# we now know which column to place the card in, but
			# not where in that column
			
			kanban::move $w $card $newcol $before
		}
		
		# mark drag operation as done.
		dict unset dragged_item $w
	}
	
	$w  configure -cursor arrow	
}

# ---------------------------------------------------------------------------

proc kanban::set-drag-highlight {w new} {
	variable dragged_highlight
	variable dragged_highlight_bg
		
	# get the old highlighted card
	set old ""
	if {[dict exists $dragged_highlight $w]} {
		set old [dict get $dragged_highlight $w]
	}

	if {$old ne $new} {
		# set old style to old card
		if {$old ne ""} {
			set oldbg [dict get $dragged_highlight_bg $w]
			$old configure -background $oldbg
			dict unset dragged_highlight $w
			dict unset dragged_highlight_bg $w
		}

		# set new style to new card		
		if {$new ne ""} {
			set newbg [$new cget -background]
			dict set dragged_highlight_bg $w $newbg
			dict set dragged_highlight $w $new
			$new configure -background "#f00" 
			$w configure -cursor sb_up_arrow
		} else {
			$w configure -cursor bottom_side  
		}
	}
	
	return $old
}

# ---------------------------------------------------------------------------

proc kanban::col-for-pos {w x y} {
	lassign [grid location $w $x $y] gridcol gridrow 

	if {$gridrow >= 0 && $gridrow <= 1} {
		return [expr {int($gridcol / 2)}]
	} else {
		return -1
	}
}

# ---------------------------------------------------------------------------

proc kanban::containerwindow {w col} {
	variable numcols

	if {$col < 1 || $col > [dict get $numcols $w]} {
		error "column $col does not exist"
	}
	
	return $w.container-$col
}
# ---------------------------------------------------------------------------

proc kanban::cardwindow {w card} {
	variable card_to_column
	if {![kanban::exists $w $card]} {
		error "card $card does not exist"
	}
	set col [kanban::cardcol $w $card]
	return $w.container-$col.content.card-$card
}

# ---------------------------------------------------------------------------

proc kanban::itemconfigure {w card args} {
	variable card_to_column
	variable itemoptkeys

	set cw [kanban::cardwindow $w $card]
	uplevel 1 $cw configure $args
}

# ---------------------------------------------------------------------------

proc kanban::itemcget {w card optkey} {
	variable itemoptkeys

	set cw [kanban::cardwindow $w $card]
	
	switch [tcl::prefix match -exact $itemoptkeys $optkey] {
		-text { $cw cget -text }
	}
}

# ---------------------------------------------------------------------------

proc kanban::exists {w card} {
	variable card_to_column
	dict exists $card_to_column $w $card
}

# ---------------------------------------------------------------------------

proc kanban::cardcol {w card} {
	variable card_to_column
	dict get $card_to_column $w $card
}

# ---------------------------------------------------------------------------

proc kanban::move {w card tocol {before ""}} {

	set cw [kanban::cardwindow $w $card]
	
	# save old widget config 
	set opts [$cw configure] 
	
	# remove old widget
	destroy $cw
	
	# add widget to new column
	set cw [kanban::add-card-to-col $w $card $tocol $before]
	
	# apply old widget config
	foreach o $opts {
		lassign $o key _1 _2 defval value
		if {$value ne {}} {
			$cw configure $key $value
		}
	}
	
}

# ---------------------------------------------------------------------------

proc kanban::delete {w card} {
	# remove in registry
	
	if {[kanban::exists $w $card]} {
		
		# remove card widget
		set cw [kanban::cardwindow $w $card]
		destroy $cw

		# remove card from internal storage
		variable card_to_column
		dict unset card_to_column $w $card		

	} else {
		error "card $card does not exist"
	}

}

# ---------------------------------------------------------------------------

proc kanban::bind {w card args} {
	set cw [kanban::cardwindow $w $card]
	uplevel 1 ::bind $cw $args
}

# ---------------------------------------------------------------------------

proc kanban::foreach-card {w itemvar body} {
 	variable card_to_column
	set keys [dict keys [dict get $card_to_column $w]]
	uplevel 1 foreach $itemvar [list $keys] [list $body]
}

# ---------------------------------------------------------------------------

proc kanban::cards {w} {
 	variable card_to_column
	dict keys [dict get $card_to_column $w]
}
