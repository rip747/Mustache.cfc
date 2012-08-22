<cfcomponent extends="mxunit.framework.TestCase">

	<cffunction name="setup">
		<cfset partials = {} />
		<cfset stache = createObject("component", "MustacheOverride").init() />
	</cffunction>

	<cffunction name="tearDown">
		<!---// make sure tests are case sensitive //--->
		<cfset assertEqualsCase(expected, stache.render(template, context, partials))/>
		<!---// reset variables //--->
		<cfset partials = {} />
		<cfset context = {} />
	</cffunction>

  <cffunction name="textEncode">
    <cfset context = { thing = 'World'} />
    <cfset template = "Hello, {{{thing}}}!" />
    <cfset expected = "Hello, `World`!" />
  </cffunction>

  <cffunction name="htmlEncode">
    <cfset context = { thing = 'World'} />
    <cfset template = "Hello, {{thing}}!" />
    <cfset expected = "Hello, |World|!" />
  </cffunction>

</cfcomponent>