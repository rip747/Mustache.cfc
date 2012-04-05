<cfcomponent output="false" extends="RenderTest">

	<cfimport taglib="../mustache" prefix="stache" />

	<cffunction name="tearDown">
		<cfset var result = "" />
		<cfsavecontent variable="result"><stache:mustache context="#context#" partials="#partials#" mustache="#stache#"><cfoutput>#template#</cfoutput></stache:mustache></cfsavecontent>
		<cfset assertEquals(expected, result)/>
	</cffunction>

</cfcomponent>