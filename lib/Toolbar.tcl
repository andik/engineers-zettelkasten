# ===========================================================================
# Toolbar Component
# ===========================================================================
#
# Example:
#
# set tb [Toolbar new .toolbar]
# $tb add "" cmd-file-new-32x32 on-new
# $tb add "" cmd-file-open-32x32 on-open
# $tb add "" cmd-file-save-32x32 on-save
# $tb add "" cmd-file-save-as-32x32 on-save-as
# $tb add-sep
# $tb add "" cmd-undo-32x32 cmd-undo
# $tb add-sep
# $tb add "Cut" cmd-cut-32x32 cmd-cut
# $tb add "Copy" cmd-copy-32x32 cmd-copy
# $tb add "Paste" cmd-paste-32x32 cmd-paste
# $tb add-sep
# $tb add-radio "" note-4-down on-set-mode mode note
# $tb add-sep
# $tb add-radio "" note-1-up on-set-notelen notelen 1
# $tb add-radio "" note-2-up on-set-notelen notelen 2
# $tb add-radio "" note-4-up on-set-notelen notelen 4
# $tb add-radio "" note-8-up on-set-notelen notelen 8
# $tb add-radio "" note-16-up on-set-notelen notelen 16
# $tb add-radio "" note-32-up on-set-notelen notelen 32
# pack .toolbar -fill x


oo::class create Toolbar {
	variable m_path
	variable m_count

	# ---------------------------------------------------------------------------

	constructor {path} {
		set m_path  $path
		set m_count 0
		ttk::frame $path
	}

	# ---------------------------------------------------------------------------

	method add {label image command} {
		set w $m_path.b-$m_count
		ttk::button $w -text $label -command $command -takefocus 0 \
			-style Toolbutton -compound left -image $image 
		pack $w -side left -fill y
		incr m_count
		return $w
	}

	# ---------------------------------------------------------------------------

	method add-label {label image} {
		set w $m_path.b-$m_count
		ttk::label $w -text $label -takefocus 0  -padding [list 5 0 5 0]\
			 -compound left -image $image
		pack $w -side left -fill y
		incr m_count
		return $w
	}

	# ---------------------------------------------------------------------------

	method add-disp {variable} {
		set w $m_path.b-$m_count
		ttk::label $w -textvariable $variable -takefocus 0 \
			-padding [list 5 0 5 0]
		pack $w -side left -fill y
		incr m_count
		return $w
	}

	# ---------------------------------------------------------------------------

	method add-check {label image command variable} {
		set w $m_path.b-$m_count
		ttk::checkbutton $w -text $label -command $command  -takefocus 0 \
			-style Toolbutton -compound left -image $image \
			-variable $variable
		pack $w -side left -fill y
		incr m_count
		return $w
	}
 
	# ---------------------------------------------------------------------------

	method add-radio {label image command variable value} {
		set w $m_path.b-$m_count
		ttk::radiobutton $w -text $label -command $command  -takefocus 0 \
			-style Toolbutton -compound left -image $image \
			-variable $variable -value $value
		pack $w -side left -fill y
		incr m_count
		return $w
	} 
	# ---------------------------------------------------------------------------

	method add-menubutton {label image command menu} {
		set w $m_path.b-$m_count
		ttk::menubutton  $w -text $label -takefocus 0 \
			-style Toolbutton -compound left -image $image \
			-menu $menu
		pack $w -side left -fill y
		incr m_count
		return $w
	}

	# ---------------------------------------------------------------------------

	method add-sep {} {
		set w $m_path.b-$m_count
		ttk::separator $w -orient vertical
		pack $w -side left -fill y
		incr m_count
		return $w
	}

	# ---------------------------------------------------------------------------

	method add-combo {label variable values args} {
		my add-label $label ""
		set w $m_path.b-$m_count
		ttk::combobox $w -textvariable $variable -values $values {*}$args
		pack $w -side left -fill y
		incr m_count
		return $w
	}
}
