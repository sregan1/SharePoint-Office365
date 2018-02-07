// Add a style string via js
function addStyleString(str) {
    var node = document.createElement('style');
    node.innerHTML = str;
    document.body.appendChild(node);
}

// Set styles for the Search Results web part
addStyleString('.cbs-Item {padding-bottom: 2px;} .cbs-Item h3 {padding-top: 10px;} .ms-promlink-headerNav {float: left;} .cbs-Line2 {padding-left: 10px;} .folder-path {color: #BBB !important; padding-left: 10px;}');

// Set styles for Site Refinement web part
addStyleString('.teamLandingTable { display: inline-table; width: 33%; } .teamLandingTitle { font-family: flama; font-weight: normal; font-style: normal; font-size:14pt; max-width:33%; color:#414141 !important; } .teamLandingDescription{ word-wrap:break-word; padding-bottom:30px; padding-right:20px; }');

