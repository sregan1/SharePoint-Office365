<!--// the page expects the following format: https://vivity.sharepoint.com/Pages/Survey-Check.aspx?path=/Lists/Survey/NewForm.aspx&title=Survey -->

<script src="https://ajax.googleapis.com/ajax/libs/jquery/3.2.1/jquery.min.js"></script>
<script type="text/javascript" src="/_layouts/15/sp.runtime.js"></script>
<script type="text/javascript" src="/_layouts/15/sp.js"></script>

<script type="text/javascript">

	function getParameterByName(name) {
		var url = window.location.href;
		name = name.replace(/[\[\]]/g, "\\$&");
		var regex = new RegExp("[?&]" + name + "(=([^&#]*)|&|#|$)"),
			results = regex.exec(url);
		if (!results) return null;
		if (!results[2]) return '';
		return decodeURIComponent(results[2].replace(/\+/g, " "));
	}

	function readSurveyVotes(cbSurveyResult)
	{
		var listTitle = getParameterByName("title");

        var context = new SP.ClientContext.get_current();
        var web = context.get_web();
        var list = web.get_lists().getByTitle(listTitle);
        var viewXml = '<View><Where><Eq><FieldRef Name="Author"/><Value Type="Integer"><UserID Type="Integer"/></Value></Eq></Where></View>';
        var query = new SP.CamlQuery();
        query.set_viewXml(viewXml);
        var items = list.getItems(query);
        context.load(items);
        context.add_requestSucceeded(onLoaded);
        context.add_requestFailed(onFailure);
        context.executeQueryAsync();
        function onLoaded() {
            var voteCount = items.get_count();
            cbSurveyResult(voteCount)
        }
        function onFailure() {
            cbSurveyResult(null);
        }
	}

	$(document).ready(function() {
		var listPath = getParameterByName("path");
		var listTitle = getParameterByName("title");

	    //Read survey for current user to find out if he have already voted   
	    readSurveyVotes(function(votesCount){
	        //if voted then display custom message 
	        if(votesCount > 0) {
	            survey-check-message.innerHTML = "<h2>You already took the " + listTitle + " survey, thank you for checking!</h2>";
	        }
	        //if not, call original function for opening response form
	        else {
	            survey-check-message.innerHTML = "<h2>Redirecting to " + listTitle +  " survey...</h2>";
	            window.location.href = listPath;
	        } 
	    });
	  
	});
        
</script>

<div id="survey-check-message" />

 