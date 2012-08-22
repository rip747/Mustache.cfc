<cfcomponent extends="mustache.Mustache">

	<cffunction name="textEncode" access="private" output="false"
		hint="Encodes a plain text string (can be overridden)">
		<cfargument name="input"/>

		<cfreturn "`" & arguments.input & "`" />
	</cffunction>

	<cffunction name="htmlEncode" access="private" output="false"
		hint="Encodes a string into HTML (can be overridden)">
		<cfargument name="input"/>

		<cfreturn "|" & arguments.input & "|" />
	</cffunction>

</cfcomponent>