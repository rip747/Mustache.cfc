<cfcomponent extends="mustache.Mustache">

	<cffunction name="textEncode" access="private" output="false"
		hint="Encodes a plain text string (can be overridden)">
		<cfargument name="input"/>
		<cfargument name="options"/>

		<!---// check the options //--->
		<cfif structKeyExists(arguments.options, "useDefault") and arguments.options.useDefault>
			<cfreturn super.textEncode(argumentCollection=arguments) />
		</cfif>

		<cfreturn "`" & arguments.input & "`" />
	</cffunction>

	<cffunction name="htmlEncode" access="private" output="false"
		hint="Encodes a string into HTML (can be overridden)">
		<cfargument name="input"/>
		<cfargument name="options"/>

		<!---// check the options //--->
		<cfif structKeyExists(arguments.options, "useDefault") and arguments.options.useDefault>
			<cfreturn super.htmlEncode(argumentCollection=arguments) />
		</cfif>

		<cfreturn "|" & arguments.input & "|" />
	</cffunction>

</cfcomponent>