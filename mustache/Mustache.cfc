<cfcomponent output="false">
	<!---//
		Mustache.cfc

		This component is a ColdFusion implementation of the Mustache logic-less templating language (see http://mustache.github.com/.)

		Key features of this implemenation:

		* Enhanced whitespace management - extra whitespace around conditional output is automatically removed
		* Partials
		* Multi-line comments
		* And can be extended via the onRenderTag event to add additional rendering logic

		Homepage:     https://github.com/rip747/Mustache.cfc
		Source Code:  https://github.com/rip747/Mustache.cfc.git

		NOTES:
		reference for string building
		http://www.aliaspooryorik.com/blog/index.cfm/e/posts.details/post/string-concatenation-performance-test-128
	//--->

	<!--- namespace for Mustache private variables (to avoid name collisions when extending Mustache.cfc) --->
	<cfset variables.Mustache = structNew() />

	<!--- captures the ".*" match for looking for formatters (see #2) and also allows nested structure references (see #3), removes looking for comments --->
	<cfset variables.Mustache.TagRegEx = createObject("java","java.util.regex.Pattern").compile("\{\{(\{|&|\>)?\s*((?:\w+(?:(?:\.\w+){1,})?)|\.)(.*?)\}?\}\}", 32)/>
	<!--- captures nested structure references --->
	<cfset variables.Mustache.SectionRegEx = createObject("java","java.util.regex.Pattern").compile("\{\{(##|\^)\s*(\w+(?:(?:\.\w+){1,})?)\s*}}(.*?)\{\{/\s*\2\s*\}\}", 32)/>
	<!--- captures nested structure references --->
	<cfset variables.Mustache.CommentRegEx = createObject("java","java.util.regex.Pattern").compile("((^\r?\n?)|\s+)?\{\{!.*?\}\}(\r?\n?(\r?\n?)?)?", 40)/>
	<!--- captures nested structure references --->
	<cfset variables.Mustache.HeadTailBlankLinesRegEx = createObject("java","java.util.regex.Pattern").compile(javaCast("string", "(^(\r?\n))|((?<!(\r?\n))(\r?\n)$)"), 32)/>
	<!--- for tracking partials --->
	<cfset variables.Mustache.partials = {}/>

	<cffunction name="init" access="public" output="false"
		hint="initalizes and returns the object">
		<cfargument name="partials" hint="the partial objects" default="#StructNew()#">

		<cfset setPartials(arguments.partials)/>

		<cfreturn this/>
	</cffunction>

	<cffunction name="render" access="public" output="false"
		hint="main function to call to a new template">
		<cfargument name="template" default="#readMustacheFile(ListLast(getMetaData(this).name, '.'))#"/>
		<cfargument name="context" default="#this#"/>
		<cfargument name="partials" hint="the partial objects" required="true" default="#structNew()#"/>

		<cfset var results = renderFragment(argumentCollection=arguments)/>

		<!--- remove single blank lines at the head/tail of the stream --->
		<cfset results = variables.Mustache.HeadTailBlankLinesRegEx.matcher(javaCast("string", results)).replaceAll("")/>

		<cfreturn results/>
	</cffunction>

	<cffunction name="renderFragment" access="private" output="false"
		hint="handles all the various fragments of the template">
		<cfargument name="template"/>
		<cfargument name="context"/>
		<cfargument name="partials" hint="the partial objects" required="true" default="#structNew()#"/>

		<!--- clean the comments from the template --->
		<cfset arguments.template = variables.Mustache.CommentRegEx.matcher(javaCast("string", arguments.template)).replaceAll("$3")/>

		<cfset structAppend(arguments.partials, variables.Mustache.partials, false)/>
		<cfset arguments.template = renderSections(arguments.template, arguments.context, arguments.partials)/>
		<cfreturn renderTags(arguments.template, arguments.context, arguments.partials)/>
	</cffunction>

	<cffunction name="renderSections" access="private" output="false">
		<cfargument name="template"/>
		<cfargument name="context"/>
		<cfargument name="partials"/>

		<cfset var local = {}/>

		<cfloop condition = "true">
			<cfset local.matches = ReFindNoCaseValues(arguments.template, variables.Mustache.SectionRegEx)/>

			<cfif arrayLen(local.matches) eq 0>
				<cfbreak/>
			</cfif>

			<cfset local.tag = local.matches[1]/>
			<cfset local.type = local.matches[2]/>
			<cfset local.tagName = local.matches[3]/>
			<cfset local.inner = local.matches[4]/>
			<cfset local.rendered = renderSection(local.tagName, local.type, local.inner, arguments.context, arguments.partials)/>

			<!--- trims out empty lines from appearing in the output --->
			<cfif len(trim(local.rendered)) eq 0>
				<cfset local.rendered = "$2"/>
			<cfelse>
				<!--- escape the backreference --->
				<cfset local.rendered = replace(local.rendered, "$", "\$", "all")/>
			</cfif>

			<!--- we use a regex to remove unwanted whitespacing from appearing --->
			<cfset arguments.template = createObject("java","java.util.regex.Pattern").compile(javaCast("string", "(^\r?\n?)?(\r?\n?)?\Q" & local.tag & "\E(\r?\n?)?"), 40).matcher(javaCast("string", arguments.template)).replaceAll(local.rendered)/>
		</cfloop>

		<cfreturn arguments.template/>
	</cffunction>

	<cffunction name="renderSection" access="private" output="false">
		<cfargument name="tagName"/>
		<cfargument name="type"/>
		<cfargument name="inner"/>
		<cfargument name="context"/>
		<cfargument name="partials"/>

		<cfset var local = {}/>

		<cfset local.ctx = get(arguments.tagName, arguments.context, arguments.partials)/>

		<cfif arguments.type neq "^" and isStruct(local.ctx) and !StructIsEmpty(local.ctx)>
			<cfreturn renderFragment(arguments.inner, local.ctx, arguments.partials)/>
		<cfelseif arguments.type neq "^" and isQuery(local.ctx) AND local.ctx.recordCount>
			<cfreturn renderQuerySection(arguments.inner, local.ctx, arguments.partials)/>
		<cfelseif arguments.type neq "^" and isArray(local.ctx) and !arrayIsEmpty(local.ctx)>
			<cfreturn renderArraySection(arguments.inner, local.ctx, arguments.partials)/>
		<cfelseif arguments.type neq "^" and structKeyExists(arguments.context, arguments.tagName) and isCustomFunction(arguments.context[arguments.tagName])>
			<cfreturn renderLambda(arguments.tagName, arguments.inner, arguments.context, arguments.partials)/>
		</cfif>

		<cfif arguments.type eq "^" xor convertToBoolean(local.ctx)>
			<cfreturn arguments.inner/>
		</cfif>

		<cfreturn ""/>
	</cffunction>

	<cffunction name="renderLambda" access="private" output="false"
		hint="render a lambda function (also provides a hook if you want to extend how lambdas works)">
		<cfargument name="tagName"/>
		<cfargument name="template" />
		<cfargument name="context" />
		<cfargument name="partials"/>

		<cfset var local = {} />

		<!--- if running on a component --->
		<cfif isObject(arguments.context)>
			<!--- call the function and pass in the arguments --->
			<cfinvoke component="#arguments.context#" method="#arguments.tagName#" returnvariable="local.results">
				<cfinvokeargument name="1" value="#arguments.template#" />
			</cfinvoke>
		<!--- otherwise we have a struct w/a reference to a function or closure --->
		<cfelse>
			<cfset local.fn = arguments.context[arguments.tagName] />
			<cfset local.results = local.fn(arguments.template) />
		</cfif>

		<cfreturn local.results />
	</cffunction>

	<cffunction name="convertToBoolean" access="private" output="false">
		<cfargument name="value"/>

		<cfif isBoolean(arguments.value)>
			<cfreturn arguments.value/>
		</cfif>
		<cfif isSimpleValue(arguments.value)>
			<cfreturn arguments.value neq ""/>
		</cfif>
		<cfif isStruct(arguments.value)>
			<cfreturn !StructIsEmpty(arguments.value)>
		</cfif>
		<cfif isQuery(arguments.value)>
			<cfreturn arguments.value.recordcount neq 0/>
		</cfif>
		<cfif isArray(arguments.value)>
			<cfreturn !arrayIsEmpty(arguments.value)>
		</cfif>

		<cfreturn false>
	</cffunction>

	<cffunction name="renderQuerySection" access="private" output="false">
		<cfargument name="template"/>
		<cfargument name="context"/>
		<cfargument name="partials"/>

		<cfset var results = []/>

		<!--- trim the trailing whitespace--so we don't print extra lines --->
		<cfset arguments.template = rtrim(arguments.template)/>

		<cfloop query="arguments.context">
			<cfset arrayAppend(results, renderFragment(arguments.template, arguments.context, arguments.partials))/>
		</cfloop>
		<cfreturn arrayToList(results, "")/>
	</cffunction>

	<cffunction name="renderArraySection" access="private" output="false">
		<cfargument name="template"/>
		<cfargument name="context"/>
		<cfargument name="partials"/>

		<cfset var local = {}/>

		<!--- trim the trailing whitespace--so we don't print extra lines --->
		<cfset arguments.template = rtrim(arguments.template)/>

		<cfset local.results = []/>
		<cfloop array="#arguments.context#" index="local.item">
			<cfset arrayAppend(local.results, renderFragment(arguments.template, local.item, arguments.partials))/>
		</cfloop>
		<cfreturn arrayToList(local.results, "")/>
	</cffunction>

	<cffunction name="renderTags" access="private" output="false">
		<cfargument name="template"/>
		<cfargument name="context"/>
		<cfargument name="partials"/>

		<cfset var local = {}/>

		<cfloop condition = "true" >

			<cfset local.matches = ReFindNoCaseValues(arguments.template, variables.Mustache.TagRegEx)/>

			<cfif arrayLen(local.matches) eq 0>
				<cfbreak/>
			</cfif>

			<cfset local.tag = local.matches[1]/>
			<cfset local.type = local.matches[2]/>
			<cfset local.tagName = local.matches[3]/>
			<!--- gets the ".*" capture --->
			<cfset local.extra = local.matches[4]/>
			<cfset arguments.template = replace(arguments.template, local.tag, renderTag(local.type, local.tagName, arguments.context, arguments.partials, local.extra))/>

		</cfloop>

		<cfreturn arguments.template/>
	</cffunction>

	<cffunction name="renderTag" access="private" output="false">
		<cfargument name="type"/>
		<cfargument name="tagName"/>
		<cfargument name="context"/>
		<cfargument name="partials"/>
		<cfargument name="extra" hint="The text appearing after the tag name"/>

		<cfset var local = {}/>
		<cfset var results = ""/>
		<cfset var extras = listToArray(arguments.extra, ":")/>

		<cfif arguments.type eq "!">
			<cfreturn ""/>
		<cfelseif (arguments.type eq "{") or (arguments.type eq "&")>
			<cfset arguments.value = get(arguments.tagName, arguments.context, arguments.partials)/>
			<cfset arguments.valueType = "text"/>
			<cfset results = textEncode(arguments.value)/>
		<cfelseif arguments.type eq ">">
			<cfset arguments.value = renderPartial(arguments.tagName, arguments.context, arguments.partials)/>
			<cfset arguments.valueType = "partial"/>
			<cfset results = arguments.value/>
		<cfelse>
			<cfset arguments.value = get(arguments.tagName, arguments.context, arguments.partials)/>
			<cfset arguments.valueType = "html"/>
			<cfset results = htmlEncode(arguments.value)/>
		</cfif>

		<cfreturn onRenderTag(results, arguments)/>
	</cffunction>

	<cffunction name="textEncode" access="private" output="false"
		hint="Encodes a plain text string (can be overridden)">
		<cfargument name="input"/>

		<!--- we normally don't want to do anything, but this function is manually so we can overwrite the default behavior of {{{token}}} --->
		<cfreturn arguments.input />
	</cffunction>

	<cffunction name="htmlEncode" access="private" output="false"
		hint="Encodes a string into HTML (can be overridden)">
		<cfargument name="input"/>

		<cfreturn htmlEditFormat(arguments.input)/>
	</cffunction>

	<cffunction name="onRenderTag" access="private" output="false"
		hint="override this function in your methods to provide additional formatting to rendered content">
		<cfargument name="rendered"/>
		<cfargument name="options" hint="Arguments supplied to the renderTag() function"/>

		<!--- do nothing but return the passed in value --->
		<cfreturn arguments.rendered/>
	</cffunction>

	<cffunction name="renderPartial"  access="private" output="false"
		hint="If we have the partial registered, use that, otherwise use the registered text">
		<cfargument name="name" hint="the name of the partial" required="true">
		<cfargument name="context" hint="the context" required="true">
		<cfargument name="partials" hint="the partial objects" required="true">

		<cfif structKeyExists(arguments.partials, arguments.name)>
			<cfreturn render(arguments.partials[arguments.name], arguments.context, arguments.partials)/>
		<cfelse>
			<cfreturn render(readMustacheFile(arguments.name), arguments.context, arguments.partials)/>
		</cfif>

	</cffunction>

	<cffunction name="readMustacheFile" access="private" output="false">
		<cfargument name="filename"/>

		<cfset var template= ""/>

		<cffile action="read" file="#getDirectoryFromPath(getMetaData(this).path)##arguments.filename#.mustache" variable="template"/>
		<cfreturn trim(template)/>
	</cffunction>

	<cffunction name="get" access="private" output="false">
		<cfargument name="key"/>
		<cfargument name="context"/>
		<cfargument name="partials"/>

		<cfset var local = {}/>

		<!--- if we are the implicit iterator --->
		<cfif arguments.key eq ".">
			<cfreturn toString(context) />
		<!--- if we're a nested key, do a nested lookup --->
		<cfelseif find(".", arguments.key)>
			<cfset local.key = listRest(arguments.key, ".")/>
			<cfset local.root = listFirst(arguments.key, ".")/>
			<cfif structKeyExists(arguments.context, local.root)>
				<cfreturn get(local.key, context[local.root], arguments.partials)/>
			<cfelse>
				<cfreturn ""/>
			</cfif>
		<cfelseif isStruct(arguments.context) && structKeyExists(arguments.context, arguments.key) >
			<cfif isCustomFunction(arguments.context[arguments.key])>
				<cfreturn renderLambda(arguments.key, '', arguments.context, arguments.partials)/>
			<cfelse>
				<cfreturn arguments.context[arguments.key]/>
			</cfif>
		<cfelseif isQuery(arguments.context)>
			<cfif listContainsNoCase(arguments.context.columnList, arguments.key)>
				<cfreturn arguments.context[arguments.key][arguments.context.currentrow]/>
			<cfelse>
				<cfreturn ""/>
			</cfif>
		<cfelse>
			<cfreturn ""/>
		</cfif>
	</cffunction>

	<cffunction name="ReFindNoCaseValues" access="private" output="false">
		<cfargument name="text"/>
		<cfargument name="re"/>

		<cfset var local = {}>

		<cfset local.results = []/>
		<cfset local.matcher = arguments.re.matcher(arguments.text)/>
		<cfset local.i = 0/>
		<cfset local.nextMatch = ""/>
		<cfif local.matcher.Find()>
			<cfloop index="local.i" from="0" to="#local.matcher.groupCount()#">
				<cfset local.nextMatch = local.matcher.group(local.i)/>
				<cfif isDefined('local.nextMatch')>
					<cfset arrayAppend(local.results, local.nextMatch)/>
				<cfelse>
					<cfset arrayAppend(local.results, "")/>
				</cfif>
			</cfloop>
		</cfif>

		<cfreturn local.results/>
	</cffunction>

	<cffunction name="getPartials" access="public" output="false">
		<cfreturn variables.Mustache.partials/>
	</cffunction>

	<cffunction name="setPartials" access="public" output="false">
		<cfargument name="partials" required="true">

		<cfset variables.Mustache.partials = arguments.partials/>
	</cffunction>

</cfcomponent>
