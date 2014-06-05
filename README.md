nagios-check_elasticsearch.sh
=============================

###Description###
check_elasticsearch.sh is a Nagios plugin to check the cluster status of elasticsearch.
    It also parses the status page to get a few useful variables out, and return them in the output.

###Basic Usage###

```check_elasticsearch.sh -H localhost```

####Options####
      -H/--hostname)
         Defines the hostname. Default: localhost
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
         Defines the port. Default: 9200
      -v)
          Verbose.  Add more (-vvv or -v -v -v) for even more verbosity.
      --debug)
          Max verbosity (same as -vvvvv)

      -h|--help)
          You're looking at it.
      -V|--version)
          Just version info

###License###
[BSD 2-clause](http://opensource.org/licenses/BSD-2-Clause)
Copyright (c) 2014, Jeff Vier < jeff@jeffvier.com>
All rights reserved.

###Author###
Jeff Vier <jeff@jeffvier.com>
