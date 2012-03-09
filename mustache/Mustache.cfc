<!---
Mustache.cfc
https://github.com/pmcelhaney/Mustache.cfc

The MIT License

Copyright (c) 2009 Chris Wanstrath (Ruby)
Copyright (c) 2010 Patrick McElhaney (ColdFusion)

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--->

<cfcomponent output="false">

	<!---
	reference for string building
	http://www.aliaspooryorik.com/blog/index.cfm/e/posts.details/post/string-concatenation-performance-test-128
	 --->

	<cfset variables.SectionRegEx = CreateObject("java","java.util.regex.Pattern").compile("\{\{(##|\^)\s*(\w+)\s*}}(.*?)\{\{/\s*\2\s*\}\}", 32)>
	<cfset variables.TagRegEx = CreateObject("java","java.util.regex.Pattern").compile("\{\{(!|\{|&|\>)?\s*(\w+).*?\}?\}\}", 32) />
	<cfset variables.partials = {} />

	<cffunction name="init" output="false">
		<cfargument name="partials" hint="the partial objects" default="#{}#">

		<cfset variables.partials = arguments.partials />
		<cfreturn this />
	</cffunction>

	<cffunction name="render" output="false">
		<cfargument name="template" default="#readMustacheFile(ListLast(getMetaData(this).name, '.'))#"/>
		<cfargument name="context" default="#this#"/>
		<cfargument name="partials" hint="the partial objects" required="true" default="#{}#">

		<cfset structAppend(arguments.partials, variables.partials, false)/>
		<cfset arguments.template = renderSections(arguments.template, arguments.context, arguments.partials) />
		<cfreturn renderTags(arguments.template, arguments.context, arguments.partials)/>
	</cffunction>

	<cffunction name="renderSections" access="private" output="false">
		<cfargument name="template" />
		<cfargument name="context" />
		<cfargument name="partials" />
		<cfset var loc = {}>
	
		<cfloop condition = "true">
			<cfset loc.matches = ReFindNoCaseValues(arguments.template, variables.SectionRegEx)>
			<cfif arrayLen(loc.matches) eq 0>
				<cfbreak>
			</cfif>
			<cfset loc.tag = loc.matches[1] />
			<cfset loc.type = loc.matches[2] />
			<cfset loc.tagName = loc.matches[3] />
			<cfset loc.inner = loc.matches[4] />
			<cfset arguments.template = replace(arguments.template, loc.tag, renderSection(loc.tagName, loc.type, loc.inner, arguments.context, arguments.partials))/>
		</cfloop>
		<cfreturn arguments.template/>
	</cffunction>

	<cffunction name="renderSection" access="private" output="false">
		<cfargument name="tagName"/>
		<cfargument name="type"/>
		<cfargument name="inner"/>
		<cfargument name="context"/>
		<cfargument name="partials" />
		<cfset var loc = {}>

		<cfset loc.ctx = get(arguments.tagName, arguments.context) />
		<cfif arguments.type neq "^" and isStruct(loc.ctx) and !StructIsEmpty(loc.ctx)>
			<cfreturn render(arguments.inner, loc.ctx, arguments.partials) />
		<cfelseif arguments.type neq "^" and isQuery(loc.ctx) AND loc.ctx.recordCount>
			<cfreturn renderQuerySection(arguments.inner, loc.ctx, arguments.partials) />
		<cfelseif arguments.type neq "^" and isArray(loc.ctx) and !ArrayIsEmpty(loc.ctx)>
			<cfreturn renderArraySection(arguments.inner, loc.ctx, arguments.partials) />
		<cfelseif arguments.type neq "^" and structKeyExists(arguments.context, arguments.tagName) and isCustomFunction(arguments.context[arguments.tagName])>
			<cfreturn evaluate("arguments.context.#arguments.tagName#(arguments.inner)") />
		</cfif>
	
		<cfif arguments.type eq "^" xor convertToBoolean(loc.ctx)>
			<cfreturn arguments.inner />
		</cfif>
		<cfreturn "" />
	</cffunction>

	<cffunction name="convertToBoolean">
		<cfargument name="value"/>
		<cfif isBoolean(arguments.value)>
			<cfreturn arguments.value />
		</cfif>
		<cfif IsSimpleValue(arguments.value)>
			<cfreturn arguments.value neq "" />
		</cfif>
		<cfif isStruct(arguments.value)>
			<cfreturn !StructIsEmpty(arguments.value)>
		</cfif>
		<cfif isQuery(arguments.value)>
			<cfreturn arguments.value.recordcount neq 0>
		</cfif>
		<cfif isArray(arguments.value)>
			<cfreturn !ArrayIsEmpty(arguments.value)>
		</cfif>
		<cfif isStruct(arguments.value)>
			<cfreturn !StructIsEmpty(arguments.value)>
		</cfif>
		<cfif isQuery(arguments.value)>
			<cfreturn arguments.value.recordcount neq 0>
		</cfif>
		<cfif isArray(arguments.value)>
			<cfreturn !ArrayIsEmpty(arguments.value)>
		</cfif>
		<cfreturn false>
	</cffunction>

	<cffunction name="renderQuerySection" access="private" output="false">
		<cfargument name="template"/>
		<cfargument name="context"/>
		<cfargument name="partials" />
		<cfset var result = [] />
		<cfloop query="arguments.context">
		<cfset ArrayAppend(result, render(arguments.template, arguments.context, arguments.partials)) />
		</cfloop>
		<cfreturn ArrayToList(result, "") />
	</cffunction>

	<cffunction name="renderArraySection" access="private" output="false">
		<cfargument name="template"/>
		<cfargument name="context"/>
		<cfargument name="partials" />
		<cfset var loc = {}>

		<cfset loc.result = [] />
		<cfloop array="#arguments.context#" index="loc.item">
			<cfset ArrayAppend(loc.result, render(arguments.template, loc.item, arguments.partials)) />
		</cfloop>
		<cfreturn ArrayToList(loc.result, "") />
	</cffunction>

	<cffunction name="renderTags" access="private" output="false">
		<cfargument name="template"/>
		<cfargument name="context" />
		<cfargument name="partials" />
		<cfset var loc = {}>
		
		<cfloop condition = "true" >
			<cfset loc.matches = ReFindNoCaseValues(arguments.template, variables.TagRegEx) />
			<cfif arrayLen(loc.matches) eq 0>
				<cfbreak>
			</cfif>
			<cfset loc.tag = loc.matches[1]/>
			<cfset loc.type = loc.matches[2] />
			<cfset loc.tagName = loc.matches[3] />
			<cfset arguments.template = replace(arguments.template, loc.tag, renderTag(loc.type, loc.tagName, arguments.context, arguments.partials))/>
		</cfloop>
		<cfreturn arguments.template/>
	</cffunction>

	<cffunction name="renderTag" access="private" output="false">
		<cfargument name="type" />
		<cfargument name="tagName" />
		<cfargument name="context" />
		<cfargument name="partials" />
		<cfif arguments.type eq "!">
			<cfreturn "" />
		<cfelseif arguments.type eq "{" or arguments.type eq "&">
			<cfreturn get(arguments.tagName, arguments.context) />
		<cfelseif arguments.type eq ">">
			<cfreturn renderPartial(arguments.tagName, arguments.context, arguments.partials) />
		<cfelse>
			<cfreturn htmlEditFormat(get(arguments.tagName, arguments.context)) />
		</cfif>
	</cffunction>
	
	<cffunction name="renderPartial" hint="If we have the partial registered, use that, otherwise use the registered text" access="private" returntype="string" output="false">
		<cfargument name="name" hint="the name of the partial" required="true">
		<cfargument name="context" hint="the context" required="true">
		<cfargument name="partials" hint="the partial objects" required="true">

		<cfif structKeyExists(arguments.partials, arguments.name)>
			<cfreturn render(arguments.partials[arguments.name], arguments.context, arguments.partials) />
		<cfelse>
			<cfreturn render(readMustacheFile(arguments.name), arguments.context, arguments.partials) />
		</cfif>

	</cffunction>

	<cffunction name="readMustacheFile" access="private" output="false">
		<cfargument name="filename" />
		<cfset var template="" />
		<cffile action="read" file="#getDirectoryFromPath(getMetaData(this).path)##arguments.filename#.mustache" variable="template"/>
		<cfreturn trim(template)/>
	</cffunction>

	<cffunction name="get" access="private" output="false">
		<cfargument name="key" />
		<cfargument name="context"/>
		<cfif isStruct(arguments.context) && structKeyExists(arguments.context, arguments.key) >
			<cfif isCustomFunction(arguments.context[arguments.key])>
				<cfreturn evaluate("arguments.context.#arguments.key#('')")>
			<cfelse>
				<cfreturn arguments.context[arguments.key]/>
			</cfif>
		<cfelseif isQuery(arguments.context)>
			<cfif listContainsNoCase(arguments.context.columnList, arguments.key)>
				<cfreturn arguments.context[arguments.key][arguments.context.currentrow] />
			<cfelse>
				<cfreturn "" />
			</cfif>
		<cfelse>
			<cfreturn "" />
		</cfif>
	</cffunction>

	<cffunction name="ReFindNoCaseValues" access="private" output="false">
		<cfargument name="text"/>
		<cfargument name="re"/>
		<cfset var loc = {}>
		
		<cfset loc.results = []/>
		<cfset loc.matcher = arguments.re.matcher(arguments.text)/>
		<cfset loc.i = 0 />
		<cfset loc.nextMatch = "" />
		<cfif loc.matcher.Find()>
			<cfloop index="loc.i" from="0" to="#loc.matcher.groupCount()#">
				<cfset loc.nextMatch = loc.matcher.group(loc.i) />
				<cfif isDefined('loc.nextMatch')>
					<cfset arrayAppend(loc.results, loc.nextMatch) />
				<cfelse>
					<cfset arrayAppend(loc.results, "") />
				</cfif>
			</cfloop>
		</cfif>
		<cfreturn loc.results />
	</cffunction>

	<cffunction name="getPartials" access="public" output="false">
		<cfreturn variables.partials />
	</cffunction>

	<cffunction name="setPartials" access="public" returntype="void" output="false">
		<cfargument name="partials" required="true">
		<cfset variables.partials = arguments.partials />
	</cffunction>

</cfcomponent>