#!/usr/bin/env lua

local matchopt = require "matchopt"

local short1 = matchopt.parse { "-v+" }
short1 = short1:process { "-vvv", "-v", "v" }
assert(#short1 == 1)
assert(short1[1] == "v")
assert(not short1.v)
assert(short1["-v"] == 4)

local short2 = matchopt.parse { "-W=([^,]+)" }
short2 = short2:process { "-W", "1", "-W", "2,3", "--", "-W", "4,5" }
assert(#short2 == 2)
assert(short2[1] == "-W")
assert(short2[2] == "4,5")
assert(#short2["-W"] == 3)
assert(short2["-W"][1] == "1")
assert(short2["-W"][2] == "2")
assert(short2["-W"][3] == "3")
	

local long_only = matchopt.parse {
	"--M",
	"--help",
	"--verbose+",
	"--lang=([^,%z]+)"
}

long_only = long_only:process { "--help", "--verbose",
    "--lang", "en,de,fr", "--verbose", "--", "--verbose" }

assert(#long_only == 1)
assert(long_only[1] == "--verbose")
assert(long_only.verbose == 2)
assert(long_only["--verbose"] == 2)
assert(long_only.help == true)
assert(long_only["--help"] == true)
assert(long_only.M == nil)
assert(long_only["--M"] == nil)
assert(#long_only.lang == 3)
assert(long_only.lang[1] == "en")
assert(long_only.lang[2] == "de")
assert(long_only.lang[3] == "fr")
assert(long_only["--lang"] == long_only.lang)

local keyword_opts = {
     "--and",
     "--break",
     "--do",
     "--else",
     "--elseif",
     "--end",
     "--false",
     "--for",
     "--function",
     "--if",
     "--in",
     "--local",
     "--nil",
     "--not",
     "--or",
     "--repeat",
     "--return",
     "--then",
     "--true",
     "--until",
     "--while"
}

local keywords = matchopt.parse(keyword_opts):process(keyword_opts)

assert(#keywords == 0)
for _,o in ipairs(keyword_opts) do
	local k = string.sub(o, 3)
	assert(keywords[o] == true)
	assert(keywords[k] == nil)
end


local mix = matchopt.parse {
	"--help|-h",
	"--verbose|-v+",
	"-D|--increase-debug-level+",
	"-_|--env=([^=]+)=([^;%s]+)"
}

mix = mix:process { "-hvvDvv_", "PATH=/bin:/usr/bin", "--increase-debug-level" }

assert(#mix == 0)
assert(mix["-v"] == 4)
assert(mix.verbose == 4)
assert(mix["--verbose"] == 4)
assert(not mix.D)
assert(mix["-D"] == 2)
assert(mix["--increase-debug-level"] == 2)
assert(mix.help == true)
assert(mix["-h"] == true)
assert(mix["--help"] == true)
assert(#mix.env == 1)
assert(#mix.env[1] == 2)
assert(mix.env[1][1] == "PATH")
assert(mix.env[1][2] == "/bin:/usr/bin")
assert(mix.env == mix["-_"])
assert(mix.env == mix["--env"])
