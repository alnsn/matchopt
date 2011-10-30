local assert        = assert
local ipairs        = ipairs
local pairs         = pairs
local setmetatable  = setmetatable
local string        = string
local table         = table
local tostring      = tostring
local type          = type

module "matchopt"

local lua_keywords = {
     ["and"]=true,
     ["break"]=true,
     ["do"]=true,
     ["else"]=true,
     ["elseif"]=true,
     ["end"]=true,
     ["false"]=true,
     ["for"]=true,
     ["function"]=true,
     ["if"]=true,
     ["in"]=true,
     ["local"]=true,
     ["nil"]=true,
     ["not"]=true,
     ["or"]=true,
     ["repeat"]=true,
     ["return"]=true,
     ["then"]=true,
     ["true"]=true,
     ["until"]=true,
     ["while"]=true
}

-- Return non-nil iff name is a valid lua name that doesn't start with
-- the underscore (to excludes lua system names).
local function is_valid_name(name)
	return string.match(name, "^%a[%w_]*$") and not lua_keywords[name]
end

-- Two patterns with these captures: option,name,delim,gmatch_or_next.
-- If a match of the first pattern returns delim "|" then gmatch_or_next
-- is a next spec and it should be matched against the second pattern.
local optspec_patterns = {
	"^(-[-]?([%w_][%w_-]*))([+=" .. "|" .. "]?)(.*)$",
	"^(-[-]?([%w_][%w_-]*))([+="    ..     "]?)(.*)$"
}

-- Return a pattern with four captures:
-- 1) "-" if an option, "" otherwise
-- 2) options that don't have agruments (may be empty)
-- 3) a letter designating an option with an agrument (may be empty)
-- 4) options length
-- For example, shortopt_pattern { "-h", "-v+", "-l=(%w)" }
-- returns "^([-]?)([hv]*)([l]?)()"
local function shortopt_pattern(parsedspec)
	local pat1, pat2 = "", ""
	for k,v in ipairs(parsedspec) do
		if v.shortoption then
			local o = string.sub(v.shortoption, 2)
			if v.command == "=" then
				pat2 = pat2 .. o
			else
				pat1 = pat1 .. o
			end
		end
	end

	-- replace empty set with NUL
	if pat1 == "" then pat1 = "%z" end
	if pat2 == "" then pat2 = "%z" end

	return "^([-]?)([" .. pat1 .. "]*)([" .. pat2 .. "]?)()"
end


local option_keys = { "shortoption", "longoption", "name" }

local function init_or_get_gmatch_table(parsedspec, processed_args)
	local init
	for _,k in ipairs(option_keys) do
		if parsedspec[k] then
			local v = parsedspec[k]
			if processed_args[v] then
				assert(not init)
				return processed_args[v]
			end
			init = init or {}
			processed_args[v] = init
		end
	end
	assert(init)
	return init
end

local function increment_option(parsedspec, processed_args)
	for _,k in ipairs(option_keys) do
		if parsedspec[k] then
			local v = parsedspec[k]
			processed_args[v] = processed_args[v] or 0
			processed_args[v] = processed_args[v] + 1
		end
	end
end

local function set_option(parsedspec, processed_args, value)
	for _,k in ipairs(option_keys) do
		if parsedspec[k] then
			local v = parsedspec[k]
			processed_args[v] = value
		end
	end
end


local function short_options(parsedspec)
	local rv = {}
	for _,v in ipairs(parsedspec) do
		if v.shortoption then
			rv[string.sub(v.shortoption, 2)] = v
		end
	end

	return rv
end

local function process_shortopt(shortopts, o, match, processed_args)
	local o1, o2 = match[2], match[3]
	for i=1,string.len(o1) do
		local parsedspec = shortopts[string.sub(o1, i, i)]
		local command = parsedspec.command
		if command == "+" then
			increment_option(parsedspec, processed_args)
		elseif command == "" then
			set_option(parsedspec, processed_args, true)
		end
	end
	return shortopts[match[3]]
end

local function long_options(parsedspec)
	local rv = {}
	for _,v in ipairs(parsedspec) do
		if v.longoption then
			rv[v.longoption] = v
		end
	end

	return rv
end

local function process_longopt(longopts, o, processed_args)
	local opt = longopts[o]
	if opt.command == "=" then
		return opt
	end
	local parsedspec = longopts[o]
	local command = parsedspec.command
	if command == "+" then
		increment_option(parsedspec, processed_args)
	elseif command == "" then
		set_option(parsedspec, processed_args, true)
	end
end

local function process(parsedspec, args)
	local rv = {}
	local shortpat  = shortopt_pattern(parsedspec)
	local longopts  = long_options(parsedspec)
	local shortopts = short_options(parsedspec)
	local processopts = true
	local optarg
	for i,o in ipairs(args) do
		if optarg then
			local opt = init_or_get_gmatch_table(optarg, rv)

			-- Emulate `for s in string.gmatch(o, optarg.gmatch)`
			local fn,state,var = string.gmatch(o, optarg.gmatch)
			while true do
				local r = { fn(state, var) }
				var = r[1]
				if var == nil then break end
				if #r == 1 then r = r[1] end
				table.insert(opt, r)
			end

			optarg = nil
		else
			local m = { string.match(o, shortpat) }
			if m[1] ~= "-" or not processopts then
				table.insert(rv, o)
			elseif o == "--" then
				processopts = false
			else
				if m[2] ~= "" or m[3] ~= "" then
					optarg = process_shortopt(shortopts, o, m, rv)
				elseif longopts[o] then
					optarg = process_longopt(longopts, o, rv)
				else
					local s,a = string.match(o, "^([^=]+)=(.*)$")
					if not s or not longopts[s] then
						error(string.format("Bad option at %d: %s", i, o))
					end
					optarg = process_longopt(longopts, s, rv)
					-- XXX process optarg here
				end
			end
		end
	end
	return rv
end

function parse(optspecs)
	local parsedspec = {}

	for spec,specval in pairs(optspecs)
	do
		local opt = {}
		parsedspec[#parsedspec+1] = opt

		if type(spec) == "number" then
			spec = specval
		elseif type(specval) == "function" then
			opt.action = specval
		end

		assert(type(spec) == "string", "Bad option: " .. tostring(spec))

		local option,name,delim,gmatch
		local curspec = spec
		for _,pat in ipairs(optspec_patterns) do
			option,name,delim,gmatch = string.match(curspec, pat)
			assert(option, "Bad option: " .. spec)

			local optlen = string.len(option)
			if optlen == string.len(name) + 1 then
				assert(optlen == 2, "Bad option: " .. spec)
				assert(not opt.shortoption, "Bad option: " .. spec)
				opt.shortoption = option
			else
				assert(not opt.longoption, "Bad option: " .. spec)
				opt.longoption = option
				if is_valid_name(name) then
					opt.name = name
				end
			end

			if delim ~= "|" then
				break
			end

			assert(gmatch ~= "", "Bad option: " .. spec)
			curspec = gmatch
		end

		assert(delim ~= "+" or gmatch == "", "Bad option: " .. spec)

		opt.command = delim
		if gmatch ~= "" then
			opt.gmatch = gmatch
		end
	end

	setmetatable(parsedspec, { __index = {process=process} })
	return parsedspec
end
