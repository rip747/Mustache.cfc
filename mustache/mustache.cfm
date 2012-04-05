<cfsetting enablecfoutputonly="true"/>

<cfparam name="attributes.mustache" type="any" default="#createObject("component","Mustache").init()#" />
<cfparam name="attributes.context" type="any" />
<cfparam name="attributes.partials" type="struct" default="#structNew()#" />

<cfif not thisTag.hasEndTag>
	<cfthrow type="MissingEndTag" message="mustache requires an end tag" />
</cfif>

<cfif thisTag.executionMode eq "end">
	<cfset thisTag.generatedContent = attributes.mustache.render(template = thisTag.generatedContent, context = attributes.context, partials = attributes.partials) />
</cfif>

<cfsetting enablecfoutputonly="false"/>