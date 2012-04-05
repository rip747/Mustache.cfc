<!---
	Mustache.cfc
	https://github.com/dswitzer/Mustache.cfc

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

	<!---// captures the ".*" match for looking for formatters (see #2) and also allows nested structure references (see #3), removes looking for comments //--->
	<cfset variables.TagRegEx = createObject("java","java.util.regex.Pattern").compile("\{\{(\{|&|\>)?\s*(\w+(?:(?:\.\w+){1,})?)(.*?)\}?\}\}", 32) />
	<!---// captures nested structure references (see #3) //--->
	<cfset variables.SectionRegEx = createObject("java","java.util.regex.Pattern").compile("\{\{(##|\^)\s*(\w+(?:(?:\.\w+){1,})?)\s*}}(.*?)\{\{/\s*\2\s*\}\}", 32) />
	<!---// captures nested structure references (see #3) //--->
	<cfset variables.CommentRegEx = createObject("java","java.util.regex.Pattern").compile("((^\r?\n?)|\s+)?\{\{!.*?\}\}(\r?\n?(\r?\n?)?)?", 40) />
	<!---// captures nested structure references (see #3) //--->
	<cfset variables.HeadTailBlankLinesRegEx = createObject("java","java.util.regex.Pattern").compile(javaCast("string", "(^(\r?\n))|((?<!(\r?\n))(\r?\n)$)"), 32) />
	<!---// for tracking partials //--->
	<cfset variables.partials = {} />
	<cfset variables.reFindCache = {}/>

	<cffunction name="init" output="false">
		<cfargument name="partials" hint="the partial objects" default="#StructNew()#">

		<cfset setPartials(arguments.partials) />

		<cfreturn this />
	</cffunction>

	<!---// function is called for any new template //--->
	<cffunction name="render" output="false">
		<cfargument name="template" default="#readMustacheFile(ListLast(getMetaData(this).name, '.'))#" />
		<cfargument name="context" default="#this#" />
		<cfargument name="partials" hint="the partial objects" required="true" default="#structNew()#" />

		<!---// render the results //--->
		<cfset var results = renderFragment(argumentCollection=arguments) />

		<!---// remove single blank lines at the head/tail of the stream //--->
		<cfset results = variables.HeadTailBlankLinesRegEx.matcher(javaCast("string", results)).replaceAll("") />

		<cfreturn results />
	</cffunction>

	<!---// this function handles all the various fragments of the template //--->
	<cffunction name="renderFragment" output="false">
		<cfargument name="template" />
		<cfargument name="context" />
		<cfargument name="partials" hint="the partial objects" required="true" default="#structNew()#" />

		<!---// clean the comments from the template //--->
		<cfset template = variables.CommentRegEx.matcher(javaCast("string", template)).replaceAll("$3") />

		<cfset structAppend(arguments.partials, variables.partials, false) />
		<cfset arguments.template = renderSections(arguments.template, arguments.context, arguments.partials) />
		<cfreturn renderTags(arguments.template, arguments.context, arguments.partials) />
	</cffunction>

  <cffunction name="renderSections" access="private" output="false">
    <cfargument name="template" />
    <cfargument name="context" />
		<cfargument name="partials" />

    <cfset var local = {} />

    <cfloop condition = "true" >
      <cfset local.matches = ReFindNoCaseValues(template, variables.SectionRegEx) />
      <cfif arrayLen(local.matches) eq 0>
        <cfbreak />
      </cfif>
      <cfset local.tag = local.matches[1] />
      <cfset local.type = local.matches[2] />
      <cfset local.tagName = local.matches[3] />
      <cfset local.inner = local.matches[4] />
			<cfset local.rendered = renderSection(local.tagName, local.type, local.inner, arguments.context, arguments.partials) />
			<!---// trims out empty lines from appearing in the output //--->
			<cfif len(trim(local.rendered)) eq 0>
				<cfset local.rendered = "$2" />
			<cfelse>
				<!---// escape the backreference //--->
				<cfset local.rendered = replace(local.rendered, "$", "\$", "all") />
			</cfif>
			<!---// we use a regex to remove unwanted whitespacing from appearing //--->
			<cfset arguments.template = createObject("java","java.util.regex.Pattern").compile(javaCast("string", "(^\r?\n?)?(\r?\n?)?\Q" & local.tag & "\E(\r?\n?)?"), 40).matcher(javaCast("string", arguments.template)).replaceAll(local.rendered) />
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
			<cfreturn renderFragment(arguments.inner, loc.ctx, arguments.partials) />
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

		<cfreturn false>
	</cffunction>

	<cffunction name="renderQuerySection" access="private" output="false">
		<cfargument name="template"/>
		<cfargument name="context"/>
		<cfargument name="partials" />
		<cfset var result = [] />

		<!---// trim the trailing whitespace--so we don't print extra lines //--->
		<cfset arguments.template = rtrim(arguments.template) />

		<cfloop query="arguments.context">
			<cfset ArrayAppend(result, renderFragment(arguments.template, arguments.context, arguments.partials)) />
		</cfloop>
		<cfreturn ArrayToList(result, "") />
	</cffunction>

	<cffunction name="renderArraySection" access="private" output="false">
		<cfargument name="template"/>
		<cfargument name="context"/>
		<cfargument name="partials" />
		<cfset var loc = {}>

		<!---// trim the trailing whitespace--so we don't print extra lines //--->
		<cfset arguments.template = rtrim(arguments.template) />

		<cfset loc.result = [] />
		<cfloop array="#arguments.context#" index="loc.item">
			<cfset ArrayAppend(loc.result, renderFragment(arguments.template, loc.item, arguments.partials)) />
		</cfloop>
		<cfreturn ArrayToList(loc.result, "") />
	</cffunction>

  <cffunction name="renderTags" access="private" output="false">
    <cfargument name="template"/>
    <cfargument name="context" />
		<cfargument name="partials" />

    <cfset var local = {} />

    <cfloop condition = "true" >
      <cfset local.matches = ReFindNoCaseValues(arguments.template, variables.TagRegEx) />
      <cfif arrayLen(local.matches) eq 0>
        <cfbreak />
      </cfif>
      <cfset local.tag = local.matches[1]/>
      <cfset local.type = local.matches[2] />
      <cfset local.tagName = local.matches[3] />
			<!---// gets the ".*" capture //--->
      <cfset local.extra = local.matches[4] />

      <cfset arguments.template = replace(arguments.template, local.tag, renderTag(local.type, local.tagName, arguments.context, arguments.partials, local.extra)) />
    </cfloop>
    <cfreturn arguments.template />
  </cffunction>

	<cffunction name="renderTag" access="private" output="false">
    <cfargument name="type" />
    <cfargument name="tagName" />
    <cfargument name="context" />
		<cfargument name="partials" />
    <cfargument name="extra" hint="The text appearing after the tag name" />

		<cfset var local = {} />
		<cfset var results = "" />
		<cfset var extras = listToArray(arguments.extra, ":") />

    <cfif type eq "!">
			<cfreturn "" />
		<cfelseif (arguments.type eq "{") or (arguments.type eq "&")>
			<cfset results = get(arguments.tagName, arguments.context) />
		<cfelseif arguments.type eq ">">
			<cfset results = renderPartial(arguments.tagName, arguments.context, arguments.partials) />
    <cfelse>
			<cfset results = htmlEditFormat(get(arguments.tagName, arguments.context)) />
    </cfif>

		<cfreturn onRenderTag(results, arguments) />
	</cffunction>

	<!---// override this function in your methods to provide additional formatting to rendered content //--->
	<cffunction name="onRenderTag" access="private" output="false">
		<cfargument name="rendered" />
    <cfargument name="options" hint="Arguments supplied to the renderTag() function" />

		<!---// do nothing but return the passed in value //--->
		<cfreturn arguments.rendered />
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
		<cfargument name="context" />

		<cfset var local = {} />

		<!---// if we're a nested key, do a nested lookup //--->
		<cfif find(".", key)>
			<cfset local.key = listRest(key, ".") />
			<cfset local.root = listFirst(key, ".") />
			<cfif structKeyExists(context, local.root)>
				<cfreturn get(local.key, context[local.root]) />
			<cfelse>
				<cfreturn "" />
			</cfif>
		<cfelseif isStruct(arguments.context) && structKeyExists(arguments.context, arguments.key) >
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

		<!--- store the result trees in cache, save on reparsing.
			removed all scope prefixes for speed --->
		<cfset var key = text & ":" & re />
		<cfif structKeyExists(reFindCache, key)>
			<cfreturn reFindCache[key] />
		</cfif>

		<cfset var loc = {}>

		<cfset loc.results = []/>
		<cfset loc.matcher = re.matcher(text)/>
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

		<cfset reFindCache[key] = loc.results />

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