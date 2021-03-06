dnl $Id: acinclude.m4,v 1.34 2009/10/14 21:12:01 dmh Exp $
dnl UD macros for netcdf configure


dnl Convert a string to all uppercase.
dnl
define([uppercase],
[translit($1, abcdefghijklmnopqrstuvwxyz, ABCDEFGHIJKLMNOPQRSTUVWXYZ)])

dnl
dnl Check for an nm(1) utility.
dnl
AC_DEFUN([UD_PROG_NM],
[
    case "${NM-unset}" in
	unset) AC_CHECK_PROGS(NM, nm, nm) ;;
	*) AC_CHECK_PROGS(NM, $NM nm, nm) ;;
    esac
    AC_MSG_CHECKING(nm flags)
    case "${NMFLAGS-unset}" in
	unset) NMFLAGS= ;;
    esac
    AC_MSG_RESULT($NMFLAGS)
    AC_SUBST(NMFLAGS)
])

dnl Check for a Fortran type equivalent to a netCDF type.
dnl
dnl UD_CHECK_FORTRAN_NCTYPE(forttype, possibs, nctype)
dnl
AC_DEFUN([UD_CHECK_FORTRAN_NCTYPE],
[
    AC_MSG_CHECKING(for Fortran-equivalent to netCDF \"$3\")
    for type in $2; do
	cat >conftest.f <<EOF
               $type foo
               end
EOF
	doit='$FC -c ${FFLAGS} conftest.f'
	if AC_TRY_EVAL(doit); then
	    break;
	fi
    done
    rm -f conftest.f conftest.o
    AC_DEFINE_UNQUOTED($1, $type, [type definition])
    AC_MSG_RESULT($type)
    $1=$type
])


dnl Check for a Fortran type equivalent to a C type.
dnl
dnl UD_CHECK_FORTRAN_CTYPE(v3forttype, v2forttype, ctype, min, max)
dnl
AC_DEFUN([UD_CHECK_FORTRAN_CTYPE],
[
    AC_MSG_CHECKING(for Fortran-equivalent to C \"$3\")
    cat >conftest.f <<EOF
        subroutine sub(values, minval, maxval)
        implicit        none
        $2              values(5), minval, maxval
        minval = values(2)
        maxval = values(4)
        if (values(2) .ge. values(4)) then
            minval = values(4)
            maxval = values(2)
        endif
        end
EOF
    doit='$FC -c ${FFLAGS conftest.f'
    if AC_TRY_EVAL(doit); then
	mv conftest.o conftestf.o
	cat >conftest.c <<EOF
#include <limits.h>
#include <float.h>
void main()
{
$3		values[[]] = {0, $4, 0, $5, 0};
$3		minval, maxval;
void	$FCALLSCSUB($3*, $3*, $3*);
$FCALLSCSUB(values, &minval, &maxval);
exit(!(minval == $4 && maxval == $5));
}
EOF
	doit='$CC -o conftest ${CPPFLAGS} ${CFLAGS} ${LDFLAGS} conftest.c conftestf.o ${LIBS}'
	if AC_TRY_EVAL(doit); then
	    doit=./conftest
	    if AC_TRY_EVAL(doit); then
		AC_MSG_RESULT($2)
		$1=$2
		AC_DEFINE_UNQUOTED($1,$2, [take a guess])
	    else
		AC_MSG_RESULT(no equivalent type)
		unset $1
	    fi
	else
	    AC_MSG_ERROR(Could not compile-and-link conftest.c and conftestf.o)
	fi
    else
	AC_MSG_ERROR(Could not compile conftest.f)
    fi
    rm -f conftest*
])


dnl Check for a Fortran data type.
dnl
dnl UD_CHECK_FORTRAN_TYPE(varname, ftypes)
dnl
AC_DEFUN([UD_CHECK_FORTRAN_TYPE],
[
    for ftype in $2; do
	AC_MSG_CHECKING(for Fortran \"$ftype\")
	cat >conftest.f <<EOF
      subroutine sub(value)
      $ftype value
      end
EOF
	doit='$FC -c ${FFLAGS} conftest.f'
	if AC_TRY_EVAL(doit); then
	    AC_MSG_RESULT(yes)
	    $1=$ftype
	    AC_DEFINE_UNQUOTED($1, $ftype, [type thing])
	    break
	else
	    AC_MSG_RESULT(no)
	fi
    done
    rm -f conftest*
])


dnl Check for the name format of a Fortran-callable C routine.
dnl
dnl UD_CHECK_FCALLSCSUB
AC_DEFUN([UD_CHECK_FCALLSCSUB],
[
#    AC_REQUIRE([UD_PROG_FC])
    case "$FC" in
	'') ;;
	*)
	    AC_REQUIRE([UD_PROG_NM])
	    AC_BEFORE([UD_CHECK_FORTRAN_CTYPE])
	    AC_BEFORE([UD_CHECK_CTYPE_FORTRAN])
	    AC_MSG_CHECKING(for C-equivalent to Fortran routine \"SUB\")
	    cat >conftest.f <<\EOF
              call sub()
              end
EOF
	    doit='$FC -c ${FFLAGS} conftest.f'
	    if AC_TRY_EVAL(doit); then
		FCALLSCSUB=`$NM $NMFLAGS conftest.o | awk '
		    /SUB_/{print "SUB_";exit}
		    /SUB/ {print "SUB"; exit}
		    /sub_/{print "sub_";exit}
		    /sub/ {print "sub"; exit}'`
		case "$FCALLSCSUB" in
		    '') AC_MSG_ERROR(not found)
			;;
		    *)  AC_MSG_RESULT($FCALLSCSUB)
			;;
		esac
	    else
		AC_MSG_ERROR(Could not compile conftest.f)
	    fi
	    rm -f conftest*
	    ;;
    esac
])


dnl Check for a C type equivalent to a Fortran type.
dnl
dnl UD_CHECK_CTYPE_FORTRAN(ftype, ctypes, fmacro_root)
dnl
AC_DEFUN([UD_CHECK_CTYPE_FORTRAN],
[
    cat >conftestf.f <<EOF
           $1 values(4)
           data values /-1, -2, -3, -4/
           call sub(values)
           end
EOF
    for ctype in $2; do
	AC_MSG_CHECKING(if Fortran \"$1\" is C \"$ctype\")
	cat >conftest.c <<EOF
            #include <stdlib.h>
	    void $FCALLSCSUB(values)
		$ctype values[[4]];
	    {
		exit(values[[1]] != -2 || values[[2]] != -3);
	    }
EOF
	doit='$CC -c ${CPPFLAGS} ${CFLAGS} conftest.c'
	if AC_TRY_EVAL(doit); then
	    doit='$FC ${FFLAGS} -c conftestf.f'
	    if AC_TRY_EVAL(doit); then
	        doit='$FC -o conftest ${FFLAGS} ${LDFLAGS} conftestf.o conftest.o ${FLIBS} ${LIBS}'
	        if AC_TRY_EVAL(doit); then
		    doit=./conftest
		    if AC_TRY_EVAL(doit); then
		        AC_MSG_RESULT(yes)
		        cname=`echo $ctype | tr ' abcdefghijklmnopqrstuvwxyz' \
			    _ABCDEFGHIJKLMNOPQRSTUVWXYZ`
		        AC_DEFINE_UNQUOTED(NF_$3[]_IS_C_$cname, [1], [fortran to c conversion])
		        break
		    else
		        AC_MSG_RESULT(no)
		    fi
	        else
		    AC_MSG_ERROR(Could not link conftestf.o and conftest.o)
	        fi
	    else
		AC_MSG_ERROR(Could not compile conftestf.f)
	    fi
	else
	    AC_MSG_ERROR(Could not compile conftest.c)
	fi
    done
    rm -f conftest*
])


dnl Get information about Fortran data types.
dnl
AC_DEFUN([UD_FORTRAN_TYPES],
[
#    AC_REQUIRE([UD_PROG_FC])
    case "$FC" in
    '')
	;;
    *)
	AC_REQUIRE([UD_CHECK_FCALLSCSUB])
dnl	UD_CHECK_FORTRAN_TYPE(NF_INT1_T, byte integer*1 "integer(kind(1))")
dnl	UD_CHECK_FORTRAN_TYPE(NF_INT2_T, integer*2 "integer(kind(2))")
	UD_CHECK_FORTRAN_TYPE(NF_INT1_T, byte integer*1 "integer(kind=1)" "integer(selected_int_kind(2))")
	UD_CHECK_FORTRAN_TYPE(NF_INT2_T, integer*2 "integer(kind=2)" "integer(selected_int_kind(4))")
	UD_CHECK_FORTRAN_TYPE(NF_INT8_T, integer*8 "integer(kind=8)" "integer(selected_int_kind(18))")

	case "${NF_INT1_T}" in
	    '') ;;
	    *)  UD_CHECK_CTYPE_FORTRAN($NF_INT1_T, "signed char", INT1)
		UD_CHECK_CTYPE_FORTRAN($NF_INT1_T, "short", INT1)
		UD_CHECK_CTYPE_FORTRAN($NF_INT1_T, "int", INT1)
		UD_CHECK_CTYPE_FORTRAN($NF_INT1_T, "long", INT1)
		;;
	esac
	case "${NF_INT2_T}" in
	    '') ;;
	    *)  UD_CHECK_CTYPE_FORTRAN($NF_INT2_T, short, INT2)
		UD_CHECK_CTYPE_FORTRAN($NF_INT2_T, int, INT2)
		UD_CHECK_CTYPE_FORTRAN($NF_INT2_T, long, INT2)
		;;
	esac
	case "${NF_INT8_T}" in
	    '') ;;
	    *)  UD_CHECK_CTYPE_FORTRAN($NF_INT8_T, "short", INT8)
		UD_CHECK_CTYPE_FORTRAN($NF_INT8_T, "int", INT8)
		UD_CHECK_CTYPE_FORTRAN($NF_INT8_T, "long long", INT8)
		;;
	esac
	UD_CHECK_CTYPE_FORTRAN(integer, int long, INT)
	UD_CHECK_CTYPE_FORTRAN(real, float double, REAL)
	UD_CHECK_CTYPE_FORTRAN(doubleprecision, double float, DOUBLEPRECISION)

dnl	UD_CHECK_FORTRAN_NCTYPE(NCBYTE_T, byte integer*1 integer, byte)
	UD_CHECK_FORTRAN_NCTYPE(NCBYTE_T, byte integer*1 "integer(kind=1)" "integer(selected_int_kind(2))" integer, byte)

dnl	UD_CHECK_FORTRAN_NCTYPE(NCSHORT_T, integer*2 integer, short)
	UD_CHECK_FORTRAN_NCTYPE(NCSHORT_T, integer*2 "integer(kind=2)" "integer(selected_int_kind(4))" integer, short)
dnl	UD_CHECK_FORTRAN_CTYPE(NF_SHORT_T, $NCSHORT_T, short, SHRT_MIN, SHRT_MAX)

dnl	UD_CHECK_FORTRAN_NCTYPE(NCLONG_T, integer*4 integer, long)
dnl	UD_CHECK_FORTRAN_CTYPE(NF_INT_T, integer, int, INT_MIN, INT_MAX)

dnl	UD_CHECK_FORTRAN_NCTYPE(NCFLOAT_T, real*4 real, float)
dnl	UD_CHECK_FORTRAN_CTYPE(NF_FLOAT_T, $NCFLOAT_T, float, FLT_MIN, FLT_MAX)

dnl	UD_CHECK_FORTRAN_NCTYPE(NCDOUBLE_T, real*8 doubleprecision real, double)
dnl	UD_CHECK_FORTRAN_CTYPE(NF_DOUBLE_T, $NCDOUBLE_T, double, DBL_MIN, DBL_MAX)
	;;
    esac
])

AC_DEFUN([AX_F90_MODULE_FLAG],[
AC_CACHE_CHECK([fortran 90 modules inclusion flag],
ax_cv_f90_modflag,
[AC_LANG_PUSH(Fortran)
i=0
while test \( -f tmpdir_$i \) -o \( -d tmpdir_$i \) ; do
  i=`expr $i + 1`
done
mkdir tmpdir_$i
cd tmpdir_$i
AC_COMPILE_IFELSE([AC_LANG_SOURCE([module conftest_module
   contains
   subroutine conftest_routine
   write(*,'(a)') 'gotcha!'
   end subroutine conftest_routine
   end module conftest_module])
  ],[],[])
cd ..
ax_cv_f90_modflag="not found"
for ax_flag in "-I" "-M" "-p"; do
  if test "$ax_cv_f90_modflag" = "not found" ; then
    ax_save_FCFLAGS="$FCFLAGS"
    FCFLAGS="$ax_save_FCFLAGS ${ax_flag}tmpdir_$i"
    AC_COMPILE_IFELSE([AC_LANG_SOURCE([program conftest_program
       use conftest_module
       call conftest_routine
       end program conftest_program])
      ],[ax_cv_f90_modflag="$ax_flag"],[])
    FCFLAGS="$ax_save_FCFLAGS"
  fi
done
rm -fr tmpdir_$i
if test "$ax_flag" = "not found" ; then
  AC_MSG_ERROR([unable to find compiler flag for modules inclusion])
fi
AC_LANG_POP(Fortran)
])])


# ===========================================================================
#    https://www.gnu.org/software/autoconf-archive/ax_valgrind_check.html
# ===========================================================================
#
# SYNOPSIS
#
#   AX_VALGRIND_DFLT(memcheck|helgrind|drd|sgcheck, on|off)
#   AX_VALGRIND_CHECK()
#
# DESCRIPTION
#
#   AX_VALGRIND_CHECK checks whether Valgrind is present and, if so, allows
#   running `make check` under a variety of Valgrind tools to check for
#   memory and threading errors.
#
#   Defines VALGRIND_CHECK_RULES which should be substituted in your
#   Makefile; and $enable_valgrind which can be used in subsequent configure
#   output. VALGRIND_ENABLED is defined and substituted, and corresponds to
#   the value of the --enable-valgrind option, which defaults to being
#   enabled if Valgrind is installed and disabled otherwise. Individual
#   Valgrind tools can be disabled via --disable-valgrind-<tool>, the
#   default is configurable via the AX_VALGRIND_DFLT command or is to use
#   all commands not disabled via AX_VALGRIND_DFLT. All AX_VALGRIND_DFLT
#   calls must be made before the call to AX_VALGRIND_CHECK.
#
#   If unit tests are written using a shell script and automake's
#   LOG_COMPILER system, the $(VALGRIND) variable can be used within the
#   shell scripts to enable Valgrind, as described here:
#
#     https://www.gnu.org/software/gnulib/manual/html_node/Running-self_002dtests-under-valgrind.html
#
#   Usage example:
#
#   configure.ac:
#
#     AX_VALGRIND_DFLT([sgcheck], [off])
#     AX_VALGRIND_CHECK
#
#   in each Makefile.am with tests:
#
#     @VALGRIND_CHECK_RULES@
#     VALGRIND_SUPPRESSIONS_FILES = my-project.supp
#     EXTRA_DIST = my-project.supp
#
#   This results in a "check-valgrind" rule being added. Running `make
#   check-valgrind` in that directory will recursively run the module's test
#   suite (`make check`) once for each of the available Valgrind tools (out
#   of memcheck, helgrind and drd) while the sgcheck will be skipped unless
#   enabled again on the commandline with --enable-valgrind-sgcheck. The
#   results for each check will be output to test-suite-$toolname.log. The
#   target will succeed if there are zero errors and fail otherwise.
#
#   Alternatively, a "check-valgrind-$TOOL" rule will be added, for $TOOL in
#   memcheck, helgrind, drd and sgcheck. These are useful because often only
#   some of those tools can be ran cleanly on a codebase.
#
#   The macro supports running with and without libtool.
#
# LICENSE
#
#   Copyright (c) 2014, 2015, 2016 Philip Withnall <philip.withnall@collabora.co.uk>
#
#   Copying and distribution of this file, with or without modification, are
#   permitted in any medium without royalty provided the copyright notice
#   and this notice are preserved.  This file is offered as-is, without any
#   warranty.

# serial-17

dnl Configured tools
m4_define([valgrind_tool_list], [[memcheck], [helgrind], [drd], [sgcheck]])
m4_set_add_all([valgrind_exp_tool_set], [sgcheck])
m4_foreach([vgtool], [valgrind_tool_list],
           [m4_define([en_dflt_valgrind_]vgtool, [on])])

AC_DEFUN([AX_VALGRIND_DFLT],[
	m4_define([en_dflt_valgrind_$1], [$2])
])dnl

AM_EXTRA_RECURSIVE_TARGETS([check-valgrind])
m4_foreach([vgtool], [valgrind_tool_list],
	[AM_EXTRA_RECURSIVE_TARGETS([check-valgrind-]vgtool)])

AC_DEFUN([AX_VALGRIND_CHECK],[
	dnl Check for --enable-valgrind
	AC_ARG_ENABLE([valgrind],
	              [AS_HELP_STRING([--enable-valgrind], [Whether to enable Valgrind on the unit tests])],
	              [enable_valgrind=$enableval],[enable_valgrind=])

	AS_IF([test "$enable_valgrind" != "no"],[
		# Check for Valgrind.
		AC_CHECK_PROG([VALGRIND],[valgrind],[valgrind])
		AS_IF([test "$VALGRIND" = ""],[
			AS_IF([test "$enable_valgrind" = "yes"],[
				AC_MSG_ERROR([Could not find valgrind; either install it or reconfigure with --disable-valgrind])
			],[
				enable_valgrind=no
			])
		],[
			enable_valgrind=yes
		])
	])

	AM_CONDITIONAL([VALGRIND_ENABLED],[test "$enable_valgrind" = "yes"])
	AC_SUBST([VALGRIND_ENABLED],[$enable_valgrind])

	# Check for Valgrind tools we care about.
	[valgrind_enabled_tools=]
	m4_foreach([vgtool],[valgrind_tool_list],[
		AC_ARG_ENABLE([valgrind-]vgtool,
		    m4_if(m4_defn([en_dflt_valgrind_]vgtool),[off],dnl
[AS_HELP_STRING([--enable-valgrind-]vgtool, [Whether to use ]vgtool[ during the Valgrind tests])],dnl
[AS_HELP_STRING([--disable-valgrind-]vgtool, [Whether to skip ]vgtool[ during the Valgrind tests])]),
		              [enable_valgrind_]vgtool[=$enableval],
		              [enable_valgrind_]vgtool[=])
		AS_IF([test "$enable_valgrind" = "no"],[
			enable_valgrind_]vgtool[=no],
		      [test "$enable_valgrind_]vgtool[" ]dnl
m4_if(m4_defn([en_dflt_valgrind_]vgtool), [off], [= "yes"], [!= "no"]),[
			AC_CACHE_CHECK([for Valgrind tool ]vgtool,
			               [ax_cv_valgrind_tool_]vgtool,[
				ax_cv_valgrind_tool_]vgtool[=no
				m4_set_contains([valgrind_exp_tool_set],vgtool,
				    [m4_define([vgtoolx],[exp-]vgtool)],
				    [m4_define([vgtoolx],vgtool)])
				AS_IF([`$VALGRIND --tool=]vgtoolx[ --help >/dev/null 2>&1`],[
					ax_cv_valgrind_tool_]vgtool[=yes
				])
			])
			AS_IF([test "$ax_cv_valgrind_tool_]vgtool[" = "no"],[
				AS_IF([test "$enable_valgrind_]vgtool[" = "yes"],[
					AC_MSG_ERROR([Valgrind does not support ]vgtool[; reconfigure with --disable-valgrind-]vgtool)
				],[
					enable_valgrind_]vgtool[=no
				])
			],[
				enable_valgrind_]vgtool[=yes
			])
		])
		AS_IF([test "$enable_valgrind_]vgtool[" = "yes"],[
			valgrind_enabled_tools="$valgrind_enabled_tools ]m4_bpatsubst(vgtool,[^exp-])["
		])
		AC_SUBST([ENABLE_VALGRIND_]vgtool,[$enable_valgrind_]vgtool)
	])
	AC_SUBST([valgrind_tools],["]m4_join([ ], valgrind_tool_list)["])
	AC_SUBST([valgrind_enabled_tools],[$valgrind_enabled_tools])

[VALGRIND_CHECK_RULES='
# Valgrind check
#
# Optional:
#  - VALGRIND_SUPPRESSIONS_FILES: Space-separated list of Valgrind suppressions
#    files to load. (Default: empty)
#  - VALGRIND_FLAGS: General flags to pass to all Valgrind tools.
#    (Default: --num-callers=30)
#  - VALGRIND_$toolname_FLAGS: Flags to pass to Valgrind $toolname (one of:
#    memcheck, helgrind, drd, sgcheck). (Default: various)

# Optional variables
VALGRIND_SUPPRESSIONS ?= $(addprefix --suppressions=,$(VALGRIND_SUPPRESSIONS_FILES))
VALGRIND_FLAGS ?= --num-callers=30
VALGRIND_memcheck_FLAGS ?= --leak-check=full --show-reachable=no
VALGRIND_helgrind_FLAGS ?= --history-level=approx
VALGRIND_drd_FLAGS ?=
VALGRIND_sgcheck_FLAGS ?=

# Internal use
valgrind_log_files = $(addprefix test-suite-,$(addsuffix .log,$(valgrind_tools)))

valgrind_memcheck_flags = --tool=memcheck $(VALGRIND_memcheck_FLAGS)
valgrind_helgrind_flags = --tool=helgrind $(VALGRIND_helgrind_FLAGS)
valgrind_drd_flags = --tool=drd $(VALGRIND_drd_FLAGS)
valgrind_sgcheck_flags = --tool=exp-sgcheck $(VALGRIND_sgcheck_FLAGS)

valgrind_quiet = $(valgrind_quiet_$(V))
valgrind_quiet_ = $(valgrind_quiet_$(AM_DEFAULT_VERBOSITY))
valgrind_quiet_0 = --quiet
valgrind_v_use   = $(valgrind_v_use_$(V))
valgrind_v_use_  = $(valgrind_v_use_$(AM_DEFAULT_VERBOSITY))
valgrind_v_use_0 = @echo "  USE   " $(patsubst check-valgrind-%-am,%,$''@):;

# Support running with and without libtool.
ifneq ($(LIBTOOL),)
valgrind_lt = $(LIBTOOL) $(AM_LIBTOOLFLAGS) $(LIBTOOLFLAGS) --mode=execute
else
valgrind_lt =
endif

# Use recursive makes in order to ignore errors during check
check-valgrind-am:
ifeq ($(VALGRIND_ENABLED),yes)
	$(A''M_V_at)$(MAKE) $(AM_MAKEFLAGS) -k \
		$(foreach tool, $(valgrind_enabled_tools), check-valgrind-$(tool))
else
	@echo "Need to reconfigure with --enable-valgrind"
endif

# Valgrind running
VALGRIND_TESTS_ENVIRONMENT = \
	$(TESTS_ENVIRONMENT) \
	env VALGRIND=$(VALGRIND) \
	G_SLICE=always-malloc,debug-blocks \
	G_DEBUG=fatal-warnings,fatal-criticals,gc-friendly

VALGRIND_LOG_COMPILER = \
	$(valgrind_lt) \
	$(VALGRIND) $(VALGRIND_SUPPRESSIONS) --error-exitcode=1 $(VALGRIND_FLAGS)

define valgrind_tool_rule
check-valgrind-$(1)-am:
ifeq ($$(VALGRIND_ENABLED)-$$(ENABLE_VALGRIND_$(1)),yes-yes)
ifneq ($$(TESTS),)
	$$(valgrind_v_use)$$(MAKE) check-TESTS \
		TESTS_ENVIRONMENT="$$(VALGRIND_TESTS_ENVIRONMENT)" \
		LOG_COMPILER="$$(VALGRIND_LOG_COMPILER)" \
		LOG_FLAGS="$$(valgrind_$(1)_flags)" \
		TEST_SUITE_LOG=test-suite-$(1).log
endif
else ifeq ($$(VALGRIND_ENABLED),yes)
	@echo "Need to reconfigure with --enable-valgrind-$(1)"
else
	@echo "Need to reconfigure with --enable-valgrind"
endif
endef

$(foreach tool,$(valgrind_tools),$(eval $(call valgrind_tool_rule,$(tool))))

A''M_DISTCHECK_CONFIGURE_FLAGS ?=
A''M_DISTCHECK_CONFIGURE_FLAGS += --disable-valgrind

MOSTLYCLEANFILES ?=
MOSTLYCLEANFILES += $(valgrind_log_files)

.PHONY: check-valgrind $(add-prefix check-valgrind-,$(valgrind_tools))
']

	AC_SUBST([VALGRIND_CHECK_RULES])
	m4_ifdef([_AM_SUBST_NOTMAKE], [_AM_SUBST_NOTMAKE([VALGRIND_CHECK_RULES])])
])
