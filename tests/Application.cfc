<!---// set up a dummy application so that we don't need any specific mappings and the tests can run from any sub-directory //--->
<cfcomponent output="false">
	<!---// SET APPLICATION MAPPINGS //--->
	<cfset this.mappings["/tests"] = getDirectoryFromPath(getCurrentTemplatePath()) />
	<cfset this.mappings["/mustache"] = this.mappings["/tests"] & "../mustache" />

	<!---// APPLICATION CFC PROPERTIES //--->
	<cfset this.name = hash(this.mappings["/tests"]) />
	<cfset this.applicationTimeout = createTimespan(0, 0, 10, 0) />
	<cfset this.serverSideFormValidation = false />
	<cfset this.clientManagement = false />
	<cfset this.setClientCookies = false />
	<cfset this.setDomainCookies = false />
	<cfset this.sessionManagement = false />
</cfcomponent>