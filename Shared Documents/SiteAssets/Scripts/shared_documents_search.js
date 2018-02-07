<script src="https://ajax.googleapis.com/ajax/libs/jquery/3.2.1/jquery.min.js"></script>

<script type="text/javascript">

	// Get a querystring parameter from a given url and key
	function getParameterByName(name, url) {
	    if (!url) url = window.location.href;
	    name = name.replace(/[\[\]]/g, "\\$&");
	    var regex = new RegExp("[?&]" + name + "(=([^&#]*)|&|#|$)"),
	        results = regex.exec(url);
	    if (!results) return null;
	    if (!results[2]) return '';
	    return decodeURIComponent(results[2].replace(/\+/g, " "));
	}

	// Update a querystring parameter given a url, key and value
	function updateQueryStringParameter(url, key, value) {
	  var re = new RegExp("([?#&])" + key + "=.*?(&|$)", "i");
	  var separator = url.indexOf('?') !== -1 ? "&" : "?";
	  var refiners = url.indexOf('#') !== -1 ? url.substring(url.indexOf('#')) : "";
		  
	  if (url.match(re)) {
	    return url.replace(re, '$1' + key + "=" + value + '$2' + refiners);
	  }
	  else {
	    return url + separator + key + "=" + value + refiners;
	  }
	}
	
	// Submit the search based on clicking on the button or pressing enter
	function submitSearch()
	{
		var searchTerm = $("#txtSearch").val();
		
		var url = window.location.href;
				
		url = updateQueryStringParameter(url, "searchTerm", searchTerm);
				
		window.location.href = url;	
	}


	$(document).ready(function ()
	{	   
		// Submit on clicking the button
    	$("#btnSubmit").on("click", function() {   				
				submitSearch();		
 		});
 		
 		// Submit on pressing enter
 		$("#txtSearch").keypress(function(e) {
		    if(e.which == 13) {
		    	submitSearch();
			}
		});
		
		// If there is a search term, show it in the box
		var searchTerm = getParameterByName("searchTerm");
		if (searchTerm != "*")
		{
			document.getElementById("txtSearch").value	= searchTerm;
		}
	}); 
	
	
	// If the page has no parameters, redirect with a wildcard search term (otherwise the SCWP won't bring back results)	
    var searchTerm = getParameterByName("searchTerm");     
    if (searchTerm == null)
    {
    	window.location.replace(window.location.href + "?searchTerm=*")
    }	
	
</script>

<style>
	.button, .button:hover {
	    background-color: #008CBA; 
	    border: none;
	    color: white;
	    padding: 5px 10px;
	    text-align: center;
	    text-decoration: none;
	    display: inline-block;
	    font-size: 16px;
	    border-radius: 8px;
	    box-shadow: 0 4px 8px 0 rgba(0,0,0,0.2), 0 3px 10px 0 rgba(0,0,0,0.19);
	}
	tr, td {
		padding: 10px 10px 10px 10px;
	}
	}
</style>

<div id="new-site-message">
</div>
<div id="new-site-form">
	<table>
		<tr>
			<td>
				Search for a document here:
			</td>
			<td>
				<input id="txtSearch"></textarea>
			</td>
			<td>
				<div id="btnSubmit" class="button">Submit</div>
			</td>
		</tr>
	</table>
</div>

