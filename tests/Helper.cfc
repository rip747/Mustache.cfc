<cfcomponent>

	<cfset variables.crlf = chr(13) & chr(10) />
	<cfset variables.crlf2 = variables.crlf & variables.crlf />

	<cffunction name="getComplexContext" access="public">
		<cfset var context = {} />
		<cfset var context["Settings"] = {EnableEmailUpdates=true, ShowPrivateNote=false, Signature="Support Team"} />
		<cfset var context["Assignee"] = {Name="Tommy"} />
		<cfset var context["Customer"] = {Name="Jenny", Phone="867-5309"} />
		<cfset var context["Ticket"]   = {Number="1234", Subject="E-mail not working", Priority="Medium", Description="Here's a description#variables.crlf2#with some#variables.crlf2#new lines", Note="User needs to update their software to the latest version.", PrivateNote="Client doesn't want to listen to instructions"} />

		<cfreturn context />
	</cffunction>

	<cffunction name="getComplexTemplate" access="public">
		<!---// we to remove carriage returns, because the CFC doesn't have them //--->
		<cfreturn trim(replace(fileRead(expandPath("./complex.mustache")), chr(13), "", "all")) />
	</cffunction>

	<cffunction name="getComplexFormatterTemplate" access="public">
		<!---// we to remove carriage returns, because the CFC doesn't have them //--->
		<cfreturn trim(replace(fileRead(expandPath("./complexFormatter.mustache")), chr(13), "", "all")) />
	</cffunction>

</cfcomponent>