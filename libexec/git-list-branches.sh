#!/bin/bash
#
# git-list-branches --
# 
#   List branch status and age against an integration branch.
#
PROGNAME=$(basename $0)


_has_git() {
  git rev-parse HEAD > /dev/null 2>&1
}

_check_branches_format() {
  if [ $porcelain = no ] ; then
    echo "%-70s +%-6s -%-6s %-18s %s\n"
  else
    echo "%s,%s,%s,%s,%s\n"
  fi
}

_xterm_color() {
  color=$(( 16 + ($1 * 36) + ($2 * 6) + $3 ))
  case $4 in
    (bg) code=48 ;;
    (*)  code=38 ;;
  esac
  echo "\033[${code};5;${color}m"
}

_xterm_escape() {
	echo "\033[$1m"
}

_list_branches() {
  case $1 in
    remote)
      git show-ref | fgrep remotes/origin | sed -e 's:.*remotes/::'
      ;;
    local)
      git show-ref --heads | sed -e 's:.*refs/heads/::'
      ;;
  esac
}

_check_branch() {
  branch=$1
  against=$2
  ahead=$(git rev-list --abbrev-commit $branch ^$against | wc -l)
  behind=$(git rev-list --abbrev-commit $against ^$branch | wc -l)
  stamp=$(_rev_stamp $branch)
  if [ $behind -gt 0 ] ; then
    behind_last=$(git rev-list --reverse $against ^$branch | head -1)
    behind_by=$(_rev_age $behind_last)
  else
    behind_by=""
  fi
  
  branch_latest=$(git rev-list -n 1 $branch)
  who=$(_rev_author $branch_latest)

  printf "$(_check_branches_format)" $branch $ahead $behind "$behind_by" "$who"
}

_rev_age() {
  git log -1 --format='%ar' $1
}

_rev_stamp() {
  git log -1 --format='%at' $1
}

_rev_author() {
  git log -1 --format='%an' $1
}

_check_all_branches() {
  for branch in $(_list_branches $1) ; do
    _check_branch $branch $2
  done
}

_color_by_duration() {
  while read LINE ; do
    case "$LINE" in
      (*+0*)      color=$(_xterm_color 1 1 1) ;;
      (*minute*)  color=$(_xterm_color 0 5 0) ;;
      (*hour*)    color=$(_xterm_color 0 5 0) ;;
      (*days*)    color=$(_xterm_color 5 5 0) ;;
      (*week*)    color=$(_xterm_color 5 3 0) ;;
      (*month*)   color=$(_xterm_color 5 0 0) ;;
      (*year*)    color=$(_xterm_color 4 0 0) ;;
      (*)         color=$(_xterm_escape 0) ;;
    esac
    normal=$(_xterm_escape 0)
    printf "${color}${LINE}${normal}\n"
    # echo "$LINE"
  done
}

_usage() {
  echo
  echo "$(basename $0) [-l] [-r] [-i integration-branch]"
  echo
  echo "  -l : show local branches (default)"
  echo "  -r : show remote branches"
  echo "  -i [branch] : integration branch, defaults to 'origin/master'"
}

_die() {
  echo "$@" >&2
  exit 1
}

while getopts hprli: opt ; do
  case $opt in
    h) _usage ; exit 0 ;;
    p) porcelain="yes" ;;
    l) where="local" ;;
    r) where="remote" ;;
    i) against="$OPTARG" ;;
    \?) _die ;;
    :)  _die "Option -$OPTARG requires an argument." ;;
    *) echo "argument $OPTARG" ;; 
  esac
done
shift $((OPTIND-1))

[ $# -gt 0 ] && _usage && _die "Too many arguments."

_has_git || _die "Not in a git repository !"

: ${porcelain:=no}
: ${where:=local}
: ${against:=origin/master}

if [ $porcelain = no ] ; then
  echo "Listing $where branches against $against"
  printf "$(_check_branches_format)" "BRANCH NAME" "AHEAD" "BEHIND" "OLDEST UNPULLED" "AUTHOR"
  _check_all_branches $where $against |  _color_by_duration
else
  _check_all_branches $where $against
fi


