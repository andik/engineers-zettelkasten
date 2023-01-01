
# ===========================================================================
# Generic Load-Save Handling
# ===========================================================================
#
# This class implements generic textfile load-save functionality.
# This means mostly wrapping TKs open/save dialogs.
# This makes it easy to implement load/save behavior for all kind of 
# file formats / data structures.
#
# File encoding is always utf-8.
#
# Example:
# 
#		# Create the Object
#		set loadsave [LoadSave new]
#		
#		# Add a Filetype
#		$loadsave add-filetype "Text File" *.txt
#		$loadsave add-filetype "HTML File" *.html *.htm
#		
#		# Mark file modified
#		$loadsave modified 1
#
#
#	Functions which are easy-to-use in TK and implement loading/saving 
#
#		# -----------------------------------------------------------------------
#		
#		proc cmd-new {} {
#			set oldcontent [$some_state get-content-as-string]
#			if {[$::loadsave new $oldcontent]} {
#				$some_state set-content-as-string ""
#			}
#		}
#		
#		# -----------------------------------------------------------------------
#		
#		proc cmd-open {} {
#			set oldcontent [$some_state get-content-as-string]
#			if {[$::loadsave open $oldcontent content]} {
#				$some_state set-content-as-string $content
#			}
#		}
#		
#		# -----------------------------------------------------------------------
#		
#		proc cmd-save {} {
#			$::loadsave save [$some_state get-content-as-string]
#		}
#		
#		# -----------------------------------------------------------------------
#		
#		proc cmd-save-as {} {
#			$::loadsave save-as [$some_state get-content-as-string]
#		}
#
#		# -----------------------------------------------------------------------

oo::class create LoadSave {
	variable m_title     ;# Title for Dialogs
	variable m_filename  ;# save filename 
	variable m_filetypes ;# filetypes for Open/Save Dialogs
	variable m_modified  ;# file was changed?
}

# ---------------------------------------------------------------------------

oo::define LoadSave \
constructor {{title ""}} {
	set m_title $title
	set m_filename ""
	set m_modified 0
	set m_filetypes [list]
}

# ---------------------------------------------------------------------------

oo::define LoadSave \
method filename {{value ""}} {
	if {$value eq ""} {
		return $m_filename
	} else {
		set m_filename $value
	}
}

# ---------------------------------------------------------------------------

oo::define LoadSave \
method modified {{value ""}} {
	if {$value eq ""} {
		return $m_modified
	} else {
		set m_modified $value
	}
}

# ---------------------------------------------------------------------------

oo::define LoadSave \
method add-filetype {title args} {
	lappend m_filetypes [list $title $args]
}

# ---------------------------------------------------------------------------

oo::define LoadSave \
method new {oldcontent} {
	if {$m_modified && $m_filename ne ""} {
		set answer [my ask-save-dialog]
		
		if {$answer eq "yes"} {
			cmd-save $oldcontent
		} elseif {$answer eq "cancel"} {
			return 0
		}
	}

	set m_filename ""
	return 1
}

# ---------------------------------------------------------------------------

oo::define LoadSave \
method open {oldcontent destvar {filename ""}} {
	upvar 1 $destvar dest

	# 'new' saves the old document and prepares for new content
	if {[my new $oldcontent]} {

		if {$filename eq ""} {
			set m_filename [tk_getOpenFile -filetypes $m_filetypes]
		} else {
			set m_filename $filename
		}

		if {$m_filename ne ""} {
			set f [open $m_filename]
			fconfigure $f -encoding utf-8
			if {$f ne ""} {
				set dest [read $f]
				close $f
				return 1
			}
		}
	}

	return 0
}

# ---------------------------------------------------------------------------

oo::define LoadSave \
method save {content} {
	if {$m_filename eq ""} {
		my save-as $content

	} else {
		set f [open $m_filename "w"]
		if {$f ne ""} {
			fconfigure $f -encoding utf-8 -translation lf
			puts $f $content
			close $f
		}
	}
}

# ---------------------------------------------------------------------------

oo::define LoadSave \
method save-as {content {filename ""}} {
	if {$filename eq ""} {
		set m_filename [tk_getSaveFile -filetypes $m_filetypes]
	} else {
		set m_filename $filename
	}

	if {$m_filename ne ""} {
		my save $content
	}
}

# ---------------------------------------------------------------------------

oo::define LoadSave \
method ask-save-dialog {} {
	# ask for storing changes 
	tk_messageBox \
		-title $m_title \
		-message "Save File $m_filename?" \
		-type yesnocancel \
}
