<!---
	This extention to Mustache provides the following functionality:

	1) It adds Ctemplate-style "modifiers" (or formatters). You can now use the following
	   syntax with your variables:

	   Hello "{{NAME:leftPad(20):upperCase}}"

	   This would output the "NAME" variable, left justify it's output to 20 characters and
	   make the string upper case.

	   The idea is to provide a collection of common formatter functions, but a user could
	   extend this compontent to add in their own user formatters.

	   This method provides is more readable and easy to implement over the lambda functionality
	   in the default Mustache syntax.
--->
<cfcomponent extends="Mustache" output="false">

<!---
	<!---// the only difference to the original RegEx is I capture the ".*" match //--->
	<cfset variables.TagRegEx = CreateObject("java","java.util.regex.Pattern").compile("\{\{(!|\{|&|\>)?\s*(\w+)(.*?)\}?\}\}", 32) />
--->

	<!---// captures arguments to be passed to formatter functions //--->
	<cfset variables.ArgumentsRegEx = createObject("java","java.util.regex.Pattern").compile("[^\s,]*(?<!\\)\(.*?(?<!\\)\)|(?<!\\)\[.*?(?<!\\)\]|(?<!\\)\{.*?(?<!\\)\}|(?<!\\)('|"").*?(?<!\\)\1|(?:(?!,)\S)+", 40) />

	<!---// overwrite the default methods //--->
  <cffunction name="onRenderTag" access="private" output="false">
    <cfargument name="rendered" />
    <cfargument name="options" hint="Arguments supplied to the renderTag() function" />

		<cfset var local = {} />
		<cfset var results = arguments.rendered />

		<cfif not structKeyExists(arguments.options, "extra") or not len(arguments.options.extra)>
			<cfreturn results />
		</cfif>

		<cfset local.extras = listToArray(arguments.options.extra, ":") />

		<!---// look for functional calls (see #2) //--->
		<cfloop index="local.fn" array="#local.extras#">
			<!---// all formatting functions start with two underscores //--->
			<cfset local.fn = trim("__" & local.fn) />
			<cfset local.fnName = listFirst(local.fn, "(") />
			<!---// check to see if we have a function matching this fn name //--->
			<cfif structKeyExists(variables, local.fnName) and isCustomFunction(variables[local.fnName])>
				<!---// get the arguments (but ignore empty arguments) //--->
				<cfif reFind("\([^\)]+\)", local.fn)>
					<!---// get the arguments from the function name //--->
					<cfset local.args = replace(local.fn, local.fnName & "(", "") />
					<!---// gets the arguments from the string //--->
					<cfset local.args = regexMatch(left(local.args, len(local.args)-1), variables.ArgumentsRegEx) />
				<cfelse>
					<cfset local.args = [] />
				</cfif>

				<!---// call the function and pass in the arguments //--->
				<cfinvoke method="#local.fnName#" returnvariable="results">
					<cfinvokeargument name="1" value="#results#">
					<cfset local.i = 1 />
					<cfloop index="local.value" array="#local.args#">
						<cfset local.i++ />
						<cfinvokeargument name="#local.i#" value="#trim(local.value)#" />
					</cfloop>
				</cfinvoke>
			</cfif>
		</cfloop>

		<cfreturn results />
  </cffunction>

	<cffunction name="regexMatch" access="private" output="false">
		<cfargument name="text"/>
		<cfargument name="re"/>
		<cfset var loc = {}>

		<cfset loc.results = []/>
		<cfset loc.matcher = arguments.re.matcher(arguments.text)/>
		<cfset loc.i = 0 />
		<cfset loc.nextMatch = "" />
		<cfloop condition="#loc.matcher.find()#">
			<cfset loc.nextMatch = loc.matcher.group(0) />
			<cfif isDefined('loc.nextMatch')>
				<cfset arrayAppend(loc.results, loc.nextMatch) />
			<cfelse>
				<cfset arrayAppend(loc.results, "") />
			</cfif>
		</cfloop>

		<cfreturn loc.results />
	</cffunction>

	<!---//
		MUSTACHE FUNCTIONS
	 //--->
	<cffunction name="__leftPad" access="private" output="false">
		<cfargument name="value" type="string" />
		<cfargument name="length" type="numeric" />

		<cfreturn lJustify(arguments.value, arguments.length) />
	</cffunction>

	<cffunction name="__rightPad" access="private" output="false">
		<cfargument name="value" type="string" />
		<cfargument name="length" type="numeric" />

		<cfreturn rJustify(arguments.value, arguments.length) />
	</cffunction>

	<cffunction name="__upperCase" access="private" output="false">
		<cfargument name="value" type="string" />

		<cfreturn ucase(arguments.value) />
	</cffunction>

	<cffunction name="__lowerCase" access="private" output="false">
		<cfargument name="value" type="string" />

		<cfreturn lcase(arguments.value) />
	</cffunction>

	<cffunction name="__multiply" access="private" output="false">
		<cfargument name="num1" type="numeric" />
		<cfargument name="num2" type="numeric" />

		<cfreturn arguments.num1 * arguments.num2 />
	</cffunction>

</cfcomponent>