#!/bin/bash
#
# BSD Licensed (http://opensource.org/licenses/BSD-2-Clause):
#
# Copyright (c) 2014, Jeff Vier < jeff@jeffvier.com>
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without modification, are
# permitted provided that the following conditions are met:
# 
# 1. Redistributions of source code must retain the above copyright notice, this list of
# conditions and the following disclaimer.
# 
# 2. Redistributions in binary form must reproduce the above copyright notice, this list of
# conditions and the following disclaimer in the documentation and/or other materials
# provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS
# OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
# THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
# TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

PROGNAME=`basename $0`
VERSION="0.1"
AUTHOR="Jeff Vier <jeff@jeffvier.com>"

DEBUG=0
hostname="localhost"
port=9200
status_page="/_cluster/health"
perfdata=false

## Initial vars
STATELEVEL=3  ## Initial statelevel

Desc="$PROGNAME is a Nagios plugin to check the cluster status of elasticsearch.
    It also parses the status page to get a few useful variables out, and return them in the output."
    
Usage="Basic Usage:\n
    $PROGNAME -H $hostname

    Options:
      -H/--hostname)
         Defines the hostname. Default: $hostname
      -i/--initshards)
         Maximum initializing_shards. Throws alert if over. Integer pair (colon separated warn:crit). Optional.
      -d/--datamin)
         Minimum data node count. Throws critical alert if not met. Integer. Optional.
      -m/--mastermin)
         Minimum master node count. Throws critical alert if not met. Integer. Optional.
      -n/--nodemin)
         Minimum total node count. Throws critical alert if not met. Integer. Optional.
      -P/--perdata)
         Output perfdata.
      -p/--port)
         Defines the port. Default: $port
      -v)
          Verbose.  Add more (-vvv or -v -v -v) for even more verbosity.
      --debug)
          Max verbosity (same as -vvvvv)

      -h|--help)
          You're looking at it.
      -V|--version)
          Just version info
"
print_version() {
  echo -e "$PROGNAME v$VERSION"
  exit 3
}
print_help() {
  echo -e "$PROGNAME v$VERSION\nAuthor: $AUTHOR"
  echo -e "\n$Desc\n\n$Usage"
  exit 3
}
# options may be followed by one colon to indicate they have a required argument
if ! options=$(getopt -au -o d:H:hi:m:n:Pp:v -l datamin:,debug,help,hostname:,initshards:,mastermin:,nodemin:,perfdata,port: -- "$@"); then exit 1; fi

set -- $options

while [ $# -gt 0 ]; do
    case $1 in
      --debug)         DEBUG=5 ;;
      -h|--help)       print_help; exit 3 ;;
      -V|--version)    print_version $PROGNAME $VERSION; exit 3 ;;
      -v)              let DEBUG=$DEBUG+1 ;;
      -i|--initshards) inits=$2 ; shift;;
      -H|--hostname)   hostname=$2 ; shift;;
      -P|--perfdata)   perfdata=true; shift;;
      -p|--port)       port=$2 ; shift;;
      -m|--mastermin)  mastermin=$2 ; shift;;
      -d|--datamin)    datamin=$2 ; shift;;
      -n|--nodemin)    nodemin=$2 ; shift;;
      (--) shift; break;;
      (-*) echo "$0: error - unrecognized option $1" 1>&2; exit 99;;
      (*) break;;
    esac
    shift
done

[ $DEBUG -gt 5 ] && DEBUG=5

[ $DEBUG -gt 0 ] && echo "Verbosity level $DEBUG"

int_range_split () { ## pass in string to be split (if splittable)
  if [[ $1 == *:* ]]; then
    echo "${1//:/ }"
  else
    echo "$1 $1" ## We do this since we're dealing with warn/crit thresholds.  Making them match "ignores" the warning level.
  fi
}

## Split up multi-threshold parameters
inits_arr=(`int_range_split $inits`)

get_status() {
  cmd="wget -q --header Host:stats -t 4 -T 3 http://${hostname}:${port}/${status_page}?pretty=true -O-"
  [ $DEBUG -ge 3 ] && echo "Executing: ${cmd}"
  json=`$cmd`
  [ $DEBUG -ge 5 ] && echo "\$json contents: ${json}"
}

set_state() { ## pass in numeric statelevel
  if [ $1 -gt $STATELEVEL ] || [ $STATELEVEL -eq 3 ]; then
    STATELEVEL=$1
    case "$STATELEVEL" in
      3) STATE="UNKNOWN" ;;
      2) STATE="CRITICAL" ;;
      1) STATE="WARNING" ;;
      0) STATE="OK" ;;
    esac
  fi
}

get_vals() {
  name=`jsonval cluster_name`
  status=`jsonval status`
  timed_out=`jsonval timed_out`
  number_nodes=`jsonval number_of_nodes`
  number_data_nodes=`jsonval number_of_data_nodes`
  active_primary_shards=`jsonval active_primary_shards`
  active_shards=`jsonval active_shards`
  relocating_shards=`jsonval relocating_shards`
  initializing_shards=`jsonval initializing_shards`
  unassigned_shards=`jsonval unassigned_shards`
  number_master_nodes=$(($number_nodes-$number_data_nodes))
}

do_output() {
  echo -e "elasticsearch ($name) is running.
  status: $status;
  timed_out: $timed_out;
  number_of_nodes: $number_nodes;
  number_of_master_nodes: $number_master_nodes;
  number_of_data_nodes: $number_data_nodes;
  active_primary_shards: $active_primary_shards;
  active_shards: $active_shards;
  relocating_shards: $relocating_shards;
  initializing_shards: $initializing_shards;
  unassigned_shards: $unassigned_shards"
}

jsonval() { ## usage: jsonval <key>
  var=`echo $json | sed -e 's/\\\\\//\//g' -e 's/[{}]//g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | sed -e 's/\"\:\"/\|/g' -e 's/[\,]/ /g' -e 's/\"//g' | grep -w $1| cut -d":" -f2| sed -e 's/^ *//g' -e 's/ *$//g'`
  echo ${var##*|}
}

color_to_status() {
  [ $DEBUG -ge 3 ] && echo "Converting cluster color ($status) to Nagios O/W/C"
  case "$status" in
    red) set_state 2 ;;
    yellow) set_state 1 ;;
    green) set_state 0 ;;
    *) set_state 3 ;;
  esac
  EXITMESSAGE="ES cluster '$name' is $status ($STATE)"
}

eval_gt() {
  WHAT=$1 ## What are we checking?
  WTH=$2 ## Warning threshold
  CTH=$3 ## Crit threshold
  VAL=$4 ## Value being evaluated
  [ $DEBUG -ge 1 ] && echo "$WHAT is being checked"
  if [ $VAL -gt $CTH ]; then
    set_state 2
    EXITMESSAGE="$EXITMESSAGE ; $WHAT is CRITICAL ($VAL over max of $CTH)"
  elif [ $VAL -gt $WTH ]; then
    if [ $WTH -gt $CTH ]; then
      echo "ERROR - you can't have a Warning threshold greater than a Critical threshold.  Fix it."
      exit 98
    fi
    set_state 1
    EXITMESSAGE="$EXITMESSAGE ; $WHAT is WARNING ($VAL over max of $WTH)"
  fi ## There's no "OK" state, since it can only be worse than the base status, which is at least "OK" (or worse) by now
}

eval_lt() {
  WHAT=$1 ## What are we checking?
  WTH=$2 ## Warning threshold
  CTH=$3 ## Crit threshold
  VAL=$4 ## Value being evaluated
  [ $DEBUG -ge 1 ] && echo "$WHAT is being checked"
  if [ $VAL -lt $CTH ]; then
    set_state 2
    EXITMESSAGE="$EXITMESSAGE ; $WHAT is CRITICAL ($VAL of min $CTH)"
  elif [ $VAL -lt $WTH ]; then
    if [ $WTH -lt $CTH ]; then
      echo "ERROR - you can't have a Warning threshold less than a Critical threshold when we're comparing for minimums.  Fix it."
      exit 98
    fi
    set_state 1
    EXITMESSAGE="$EXITMESSAGE ; $WHAT is WARNING ($VAL of min $WTH)"
  fi ## There's no "OK" state, since it can only be worse than the base status, which is at least "OK" (or worse) by now
}

# Here we go!
get_status

if [ -z "$json" ]; then
  echo "UNKNOWN - No status content retrieved (Could not connect to server $hostname, probably)"
  exit 3
else
  get_vals
  if [ -z "$name" ]; then
    echo "UNKNOWN - Error parsing server output"
    exit 3
  else
    color_to_status
    [ -n "$inits" ] && eval_gt "Maximum initializing_shards" ${inits_arr[0]} ${inits_arr[1]} $initializing_shards
    [ -n "$nodemin" ] && eval_lt "Minimum total nodes" $nodemin $nodemin $number_nodes ## passed in threshold is passed twice to essentially negate a "warning" event
    [ -n "$mastermin" ] && eval_lt "Minimum master nodes" $mastermin $mastermin $number_master_nodes ## passed in threshold is passed twice to essentially negate a "warning" event
    [ -n "$datamin" ] && eval_lt "Minimum data nodes" $datamin $datamin $number_data_nodes ## passed in threshold is passed twice to essentially negate a "warning" event
    [ $DEBUG -ge 1 ] && do_output
  fi
fi

COMPARE=$listql


echo -n "$STATE - $EXITMESSAGE"
[ $perfdata == true ] && echo " | 'active_primary'=$active_primary_shards 'active'=$active_shards 'relocating'=$relocating_shards 'init'=$initializing_shards" || echo
exit $STATELEVEL

