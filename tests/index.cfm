<cfinvoke component="mxunit.runner.DirectoryTestSuite"
			method="run"
			directory="#expandPath('/tests')#"
			componentPath="tests"
			recurse="true"
			excludes="tests.Tests"
			returnvariable="results" />

<cfoutput>#results.getResultsOutput('extjs')# </cfoutput>
