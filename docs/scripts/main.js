// ************** Load taxallnomy info *****************

var jsonData;
$.ajax({
	//url: "https://github.com/tetsufmbio/taxallnomy/blob/master/docs/data.json",
	url: "./data.json",
	dataType: 'json',
	async: false,
	success: function(data) {
		jsonData = data;
	}
});
var rankNumber = Object.keys(jsonData.rank).length;
var date = jsonData.date;
$("#lastUpdate").text(date);
var rankData = jsonData.rank;
console.log(jsonData);

// ************** Add usage of taxallnomy api  *****************

$("#api").append("<li>http://"+location.host+"/taxallnomy/cgi-bin/taxallnomy_multi.pl</li>");
$("#apiSamples").append("<li><a href=\"./cgi-bin/taxallnomy_multi.pl?txid=9606\" target=\"_blank\">http://"+location.host+"/taxallnomy/cgi-bin/taxallnomy_multi.pl?txid=9606</a></li>");
$("#apiSamples").append("<li><a href=\"./cgi-bin/taxallnomy_multi.pl?txid=9606,9595,10090&rank=main&format=json\" target=\"_blank\">http://"+location.host+"/taxallnomy/cgi-bin/taxallnomy_multi.pl?txid=9606,9595,10090&rank=main&format=json</a></li>");
$("#apiSamples").append("<li><a href=\"./cgi-bin/taxallnomy_multi.pl?txid=9606,9595,10090&rank=custom&srank=superkingdom,family,species_group,species\" target=\"_blank\">http://"+location.host+"/taxallnomy/cgi-bin/taxallnomy_multi.pl?txid=9606,9595,10090&rank=custom&srank=superkingdom,family,species_group,species</a></li>");

// ************** Generate the buttom panel *****************

var buttons = {};
buttons.nodes = [];
/*var rankType = {
	"main":   [1,0,0,0,1,0,0,1,0,0,0,1,0,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0],
	"common": [1,1,0,0,1,1,1,1,1,0,1,1,1,0,0,1,1,1,1,0,1,0,0,0,1,0,0,0]
}*/
var mainRanks = {"superkingdom":1,"phylum":1,"class":1,"order":1,"family":1,"genus":1,"species":1};
var commonRanks = {"superkingdom":1,"kingdom":1,"phylum":1,"subphylum":1,"class":1,"superclass":1,"subclass":1,"order":1,"superorder":1,"suborder":1,"family":1,"superfamily":1,"subfamily":1,"genus":1,"subgenus":1,"species":1,"subspecies":1};
var rankType = {};
rankType.main = [];
rankType.common = [];
for (var rank in rankData){
	buttons.nodes[rankData[rank].order - 1] = {};
	buttons.nodes[rankData[rank].order - 1].label = rankData[rank].abbrev;
	buttons.nodes[rankData[rank].order - 1].name = rankData[rank].name;
	buttons.nodes[rankData[rank].order - 1].rank = rankData[rank].order;
	if (rankData[rank].name in mainRanks){
		rankType.main[rankData[rank].order - 1] = 1;
	} else {
		rankType.main[rankData[rank].order - 1] = 0;
	}
	if (rankData[rank].name in commonRanks){
		rankType.common[rankData[rank].order - 1] = 1;
		buttons.nodes[rankData[rank].order - 1].switch = 1;
	} else {
		rankType.common[rankData[rank].order - 1] = 0;
		buttons.nodes[rankData[rank].order - 1].switch = 0;
	}
}

// ************** Take data from form when ready *****************

$(document).ready(function(){
	$("form#myForm").submit(function() {
		var txidIn = $('#txidInput').val();
		txidIn = txidIn.replace(/[ \r\t\n;:]/g, ",");
		if(/[^0-9,]/.test(txidIn)){
			alert("Sorry, there is special characters in your input. Use only numbers and comma.");
		} else {
			var input =  txidIn.replace(/,+/g, ",");
			input = input.replace(/,$/, "");
			if (input == ""){
				alert("Sorry, no input was provided. Please enter a valid input.");
			} else {
				var url = "./cgi-bin/taxallnomy_getLineage.pl?txid=";
				var txidList = input.split(",");
				while(txidList.length > 0){
					var end = 100;
					if (txidList.length < 100){
						end = txidList.length;
					}
					var txidListPart = txidList.splice(0, end);
					var txidListString = txidListPart.join();
					$.ajax({
						url: url+txidListString,
					}).done(function (result){
						$('#txidInput').val("");
						includeData(result);
						update(root);
					});
				}
				
			}
		}
		return false;
	});
  
	$("form#download").submit(function() {
		var formatIn = $('input[name=format]:checked').val();
		
		if (formatIn == "svg" || formatIn == "png"){
			var controlImageDownload = 0;
			downloadTree(formatIn);
			console.log(controlImageDownload);
			return false;
		}
		var txid = [];
		var originalTxid = [];
		var originalParent = [];
		for(keys in taxData.leaf){
			originalTxid.push(keys);
			if (taxData.leaf[keys].originalParent.txid){
				originalParent[taxData.leaf[keys].originalParent.txid] = 1;
			}
		}
		for(var i = 0; i < originalTxid.length; i++){
			if (!originalParent[originalTxid[i]]){
				var txid1 = originalTxid[i];
				var arrayTxid = txid1.split("\.");
				txid.push(arrayTxid[0]);
			}
		}
		var txidIn = txid.join();
		
		var rank = [];
		for(var i = 0; i < buttons.nodes.length; i++){
			if (buttons.nodes[i].switch){
				var rankName = buttons.nodes[i].name.toLowerCase();
				rankName = rankName.replace(/ /, "_");
				rank.push(rankName);
			}
		}
		if (rank.length == 0) {
			alert("Please, select at least one taxonomic rank.");
			return false;
		} 
		var rankIn = rank.join();
		
		if(/[^0-9,]/.test(txidIn)){
			alert("Sorry, there is special characters in your input. Use only numbers and line breaks.");
		} else {
			var url = "./cgi-bin/taxallnomy_multi.pl?txid=";
			formatIn = '&format='+formatIn;
			rankIn = '&rank=custom&srank='+rank;
			var win = window.open(url+txidIn+formatIn+rankIn, '_blank');
			win.focus();
		}
		return false;
	});
  
	$('input[type=radio][name=rank]').change(function() {
		changeRank($(this).val());
	});

	// take changes on tree edition form
	$( "#treeEditionForm" ).change(function( event ) {
		fontSize = $( "input#fontSizeValueIn" ).val();
		treeBranchSizeX = $( "input#nodeDistXValueIn" ).val() / 10;
		treeBranchSizeY = $( "input#nodeDistYValueIn" ).val() / 10;
		textAngle = $( "input#textAngleValueIn" ).val();
		//linkDistanceValue = $( "input#linkValueIn" ).val();
			
		//chargeValue = $( "input#chargeValueIn" ).val()*(-1);
		
		update(root);
		return false;
	});

	$('#unclassValueIn').change(function (){
		toggleUnclassified();
	});
 
});

var fontSize = 12; // font size;
var treeNodeSize = 10;
var treeBranchSizeX = 180;
var treeBranchSizeY = 1;
var textAngle = 40;
var hideUnclassified = true;

function downloadTree(format){

	//get svg element.
	var svg = document.getElementById("treesvg");
	//var svgWidth = $('svg')[0].getBoundingClientRect().width;
	//var svgHeight = $('svg')[0].getBoundingClientRect().height;
	
	var svg2 = svg.cloneNode(true);
	var g = svg2.childNodes[0];
	var transAttr = g.getAttribute("transform");
	var transList = transAttr.split(" ");
	var scale = 1;
	if(transList[1]){
		scaleMatch = transList[1].match(/scale\(([\d\.]+)\)/);
		scale = Number(scaleMatch[1]);
	} else {
		transList[1] = "";
	}
	
	var gList = svg2.childNodes[0].getElementsByTagName("g");
	var lowerHeight = 0;
	var higherHeight = 0;
	var lowerWidth = 0;
	var higherWidth = 0;
	
	for(var i = 0; i < gList.length; i++){
		var transAttr2 = gList[i].getAttribute("transform");
		var transList2 = transAttr2.match(/translate\((-?[\d\.]+)\,(-?[\d\.]+)\)/);
		var width = Number(transList2[1]);
		var heigth = Number(transList2[2]);
		if (lowerHeight > heigth){
			lowerHeight = heigth;
		}
		if (higherHeight < heigth){
			higherHeight = heigth;
		}
		if (lowerWidth > width){
			lowerWidth = width;
		}
		if (higherWidth < width){
			higherWidth = width;
		}
	}
	
	var svgWidth = higherWidth - lowerWidth;
	var svgHeight = higherHeight - lowerHeight;
	
	lowerHeight *= -1;
	lowerHeight *= scale;
	lowerHeight += 100*scale;
	
	svgWidth *= scale;
	svgWidth += 200*scale;
	svgHeight *= scale;
	svgHeight += 200*scale;
	svg2.setAttribute("width", svgWidth);
	svg2.setAttribute("height", svgHeight);
	
	g.setAttribute("transform", "translate(50,"+lowerHeight+") "+transList[1]);
	
	var area = svgWidth*svgHeight;
	
	if (format == "svg"){
				
		//get svg source.
		var serializer = new XMLSerializer();
		var source = serializer.serializeToString(svg2);

		//add name spaces.
		if(!source.match(/^<svg[^>]+xmlns="http\:\/\/www\.w3\.org\/2000\/svg"/)){
			source = source.replace(/^<svg/, '<svg xmlns="http://www.w3.org/2000/svg"');
		}
		if(!source.match(/^<svg[^>]+"http\:\/\/www\.w3\.org\/1999\/xlink"/)){
			source = source.replace(/^<svg/, '<svg xmlns:xlink="http://www.w3.org/1999/xlink"');
		}

		//add xml declaration
		source = '<?xml version="1.0" standalone="no"?>\r\n' + source;

		//convert svg source to URI data scheme.
		var url = "data:image/svg+xml;charset=utf-8,"+encodeURIComponent(source);
		
		var dl = document.createElement("a");
		document.body.appendChild(dl); // This line makes it work in Firefox.
		dl.setAttribute("href", url);
		dl.setAttribute("download", "taxallnomy.svg");
		var evObj = document.createEvent('MouseEvents');
		evObj.initMouseEvent('click', true, true, window,0, 0, 0, 80, 20, false, false, false, false, 0, null);
		//dl.click();
		dl.dispatchEvent(evObj);
		controlImageDownload = 1;
		
	} else if (format == "png"){
		
		var doctype = '<?xml version="1.0" standalone="no"?>' + '<' + '!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">';
		// serialize our SVG XML to a string.
		//var source = (new XMLSerializer()).serializeToString(d3.select('svg').node());
		var source = (new XMLSerializer()).serializeToString(svg2);
		// create a file blob of our SVG.
		
		var blob = new Blob([ doctype + source], { type: 'image/svg+xml;charset=utf-8' });
		var url = window.URL.createObjectURL(blob);
		// Put the svg into an image tag so that the Canvas element can read it in.
		var img = document.createElement('img');
		img.setAttribute("width", svgWidth);
		img.setAttribute("heigth", svgHeight);
		 
		function triggerDownload (imgURI) {
		  var evt = new MouseEvent('click', {
			view: window,
			bubbles: false,
			cancelable: true
		  });

		  var dl = document.createElement("a");
		  document.body.appendChild(dl); // This line makes it work in Firefox.
		  dl.setAttribute("href", imgURI);
		  dl.setAttribute("download", "taxallnomy.png");
		  var evObj = document.createEvent('MouseEvents');
		  evObj.initMouseEvent('click', true, true, window,0, 0, 0, 80, 20, false, false, false, false, 0, null);
		  //dl.click();
		  dl.dispatchEvent(evObj);
		  controlImageDownload = 1;
		  //var a = document.createElement('a');
		  //a.setAttribute('download', 'taxallnomy.png');
		  //a.setAttribute('href', imgURI);
		  //a.setAttribute('target', '_blank');

		  //a.dispatchEvent(evt);
		}
		
		img.onload = function(){
		  // Now that the image has loaded, put the image into a canvas element.
		  var canvas = document.createElement("canvas");
		  //var canvas = d3.select('body').append('canvas').node();
		  canvas.width = svgWidth;
		  canvas.height = svgHeight;
		  var ctx = canvas.getContext('2d');
		  ctx.drawImage(img, 0, 0);
		  var canvasUrl = canvas.toDataURL("image/png");
		  //var img2 = d3.select('body').append('img')
		  //  .attr('width', 500)
		  //  .attr('height', 500)
		  //  .node();
		  // this is now the base64 encoded version of our PNG! you could optionally 
		  // redirect the user to download the PNG by sending them to the url with 
		  // `window.location.href= canvasUrl`.
		  triggerDownload(canvasUrl);
		  //img2.src = canvasUrl; 
		}

		img.src = url;
	
	}
	return false;
	// based on the script from http://bl.ocks.org/curran/7cf9967028259ea032e8
	
	//set url value to a element's href attribute.
	//window.open(url, '_blank');
	//you can download svg file by right click menu.
}

function addRandom(){
	var url = "./cgi-bin/taxallnomy_getLineage.pl?rand=1";
			$.ajax({
				url: url,
			}).done(function (result){			
				includeData(result);
				update(root);
			});
}

var zooming = d3.behavior.zoom();
function clearTree(){
	taxonRoot = new taxon("1.000", "root", 0, "all", 0);
	taxData.leaf = {};
	taxData.leaf["1.000"] = taxonRoot;
	for (var i = 0; i < rankNumber+1; i++){
		taxData.rank[i].taxa = []
	}
	taxData.rank[0].taxa.push(taxonRoot);

	treeData = [];
	treeData.push(taxData.leaf["1.000"]);
	root = treeData[0];
	root.x0 = height / 2;
	root.y0 = 0;
	  
	//d3.select("#tree")
	var tree = d3.select("#treesvg").selectAll("g")
		.transition()
		.duration(750)
		.attr("transform", "translate(120,230)")
		zooming.scale(1);
		zooming.translate([0,0]);
	update(root);
	
}

function goToRoot(d){
	var tree = d3.select("#treesvg").select("g")
		.transition()
		.duration(750)
		.attr("transform", "translate(120,230)");
	zooming.scale(1);
	zooming.translate([0,0]);
	
}

function includeData(intree){
	var taxon2analyse = intree.tree[0].children;
	var newTaxon2analyse = [];
	var depth = 1;
	while (depth < rankNumber+1){
		while (taxon2analyse.length > 0){
			var tax1 = taxon2analyse.shift();
			if (tax1.children){
				newTaxon2analyse = newTaxon2analyse.concat(tax1.children);
			}
			var txid1 = tax1.txid;
			if (!taxData.leaf[txid1]){
				var name1 = tax1.name;
				var parent1 = tax1.parent;
				var comname1 = tax1.comname;
				var unclass1 = tax1.unclass;
				taxData.leaf[txid1] = new taxon(txid1, name1, depth, comname1, unclass1);
				if (!taxData.leaf[parent1].children){
					taxData.leaf[parent1].children = [];			
				}
				taxData.leaf[txid1].originalParent = taxData.leaf[parent1];
				taxData.rank[depth].taxa.push(taxData.leaf[txid1]);
				if (unclass1 == 1 && hideUnclassified){
				
				} else {
					if (taxData.rank[depth].switch){
						var parentRank = depth - 1;
						var parent = taxData.leaf[parent1];
						while (!taxData.rank[parentRank].switch){
							parent = parent.originalParent;
							parentRank--;
						}
						
						if (!taxData.leaf[parent.txid].children){
							taxData.leaf[parent.txid].children = [];
						}
						//var m = taxData.leaf[parent1].children.length;
						taxData.leaf[parent.txid].children.push(taxData.leaf[txid1]);
						taxData.leaf[parent.txid].children = sortChildren(taxData.leaf[parent.txid].children);
						taxData.leaf[parent.txid].hasChildren = generateHasChildren(taxData.leaf[parent.txid].children);
						//taxData.leaf[parent.txid].hasChildren[txid1] = m;
					}
				}
				
			}
		}
		taxon2analyse = newTaxon2analyse;
		newTaxon2analyse = [];
		depth++;
	}
	
}

var taxonRoot = new taxon("1.000", "root", 0, "all", 0);
var taxData = {
	"leaf": {
		"1.000": taxonRoot
	},
	"rank": {}
}
for (var i = 0; i < rankNumber+1; i++){
	function rank(){
		this.switch = 1;
		this.taxa = [];
	}
	taxData.rank[i] = new rank;
}
taxData.rank[0].taxa.push(taxonRoot);

var treeData = [];
treeData.push(taxData.leaf["1.000"]);


function wrap(text, width) {
  text.each(function() {
	var text = d3.select(this),
		words = text.text().split(/\s+/).reverse(),
		word,
		line = [],
		lineNumber = 0,
		lineHeight = 1.1, // ems
		y = text.attr("y"),
		dy = parseFloat(text.attr("dy")),
		tspan = text.text(null).append("tspan").attr("x", 15).attr("y", y).attr("dy", dy + "em");
		console.log(text.attr("y"));
	while (word = words.pop()) {
	  line.push(word);
	  tspan.text(line.join(" "));
	  if (tspan.node().getComputedTextLength() > width) {
		line.pop();
		tspan.text(line.join(" "));
		line = [word];
		tspan = text.append("tspan").attr("x", 0).attr("y", y).attr("dy", ++lineNumber * lineHeight + dy + "em").text(word);
	  }
	}
  });
}

function changeRank(type){
	if (type == 'none'){
		for(var i = 0; i < buttons.nodes.length;i++){
			if (buttons.nodes[i].switch){
				toggleCollapse(buttons.nodes[i]);
			}
		}
	} else if (type == 'all'){
		for(var i = 0; i < buttons.nodes.length;i++){
			if (!buttons.nodes[i].switch){
				toggleCollapse(buttons.nodes[i]);
			}
		}
	} else if (type == 'main'){
		for(var i = 0; i < buttons.nodes.length;i++){
			if (buttons.nodes[i].switch != rankType.main[i]){
				toggleCollapse(buttons.nodes[i]);
			}
		}
	} else if (type == 'common'){
		for(var i = 0; i < buttons.nodes.length;i++){
			if (buttons.nodes[i].switch != rankType.common[i]){
				toggleCollapse(buttons.nodes[i]);
			}
		}
	}
	update(root);
	return false;
}

function changeRankRadio(){
	$('input[name=rank]').prop('checked', false);
}
var svgButtomTest = d3.select("#buttonTest");
updateButtonTest(buttons);
function updateButtonTest(source){
	
	var elem = svgButtomTest.selectAll("div")
		.data(source.nodes)
	
	var elemEnter = elem.enter()
		.append("div")
		.attr("class", "buttonTest")
		.text(function (d){return d.label})
		.on("click", function (d){toggleCollapse(d);changeRankRadio();update(root);});
	
	var buttons = d3.selectAll(".buttonTest")
		.classed("enable", function(d){return d.switch ? true : false})
		.classed("disable", function(d){return d.switch ? false : true})
		.attr("title", function (d){return d.switch ? "hide "+d.name : "show "+d.name})
}	

for(var i = 0; i < buttons.nodes.length; i++){
	var rankButtom = buttons.nodes[i];
	if (!rankButtom.switch){
		taxData.rank[rankButtom.rank].switch = 0;
	}
}

function toggleCollapse(d){
	
	if (d.switch){
		collapseRank(d.rank);
		d.switch = 0;
	} else {
		uncollapseRank(d.rank);
		d.switch = 1;
	}
	updateButtonTest(buttons);
	
}

// ************** Generate the tree diagram	 *****************

var margin = {top: 20, right: 120, bottom: 20, left: 120},
	width = 960 - margin.right - margin.left,
	height = 500 - margin.top - margin.bottom;
	
var i = 0,
	duration = 750,
	root;

var tree = d3.layout.tree()
	.nodeSize([40, 100]);

var diagonal = d3.svg.diagonal()
	.projection(function(d) { return [d.y, d.x]; });

//var svg = d3.select("#tree").append("svg")
var svg = d3.select("#treesvg")
	.call(zooming
	.scaleExtent([0.1, 5])
	.center([width / 2, height / 2])
	.on("zoom", zoom))
	.on("dblclick.zoom", null)
	.on("mousewheel.zoom", null)
	.on("DOMMouseScroll.zoom", null)
	.on("wheel.zoom", null)
	.append("g")	
		.attr("transform", "translate(" + margin.left + "," + height/2 + ")");

root = treeData[0];
root.x0 = height / 2;
root.y0 = 0;
  
//d3.select("#tree")
// Define the div for the tooltip
var div = d3.select("body").append("div")	
	  .attr("class", "tooltip")				
	  .style("opacity", 0);

update(root);
			  
function update(source) {

  // Compute the new tree layout.
  var nodes = tree.nodes(root).reverse(),
	  links = tree.links(nodes);
  
  //tree.separation(treeBranchSizeY);

  // Normalize for fixed-depth.
  //nodes.forEach(function(d) { d.y = d.depth * 180; });

  nodes.forEach(function(d) { d.y = d.depth * treeBranchSizeX; });
  nodes.forEach(function(d) { d.x = d.x * treeBranchSizeY; });

  // Update the nodes
  var node = svg.selectAll("g.node")
	  .data(nodes, function(d) { return d.id || (d.id = ++i); });

  // Enter any new nodes at the parent's previous position.
  var nodeEnter = node.enter().append("g")
	  .attr("class", "node")
	  .attr("transform", function(d) { return "translate(" + source.y0 + "," + source.x0 + ")"; })
	  .on("click", distinguishClick)
		.on("mouseover", function(d) {
			var tooltip = '<p style="font-size:14px"><b>'+d.name + '</b></p>';
			if (d.comname != "NULL"){
				tooltip += "<p>("+d.comname+")</p>";
			}
			tooltip += '<p style="font-size:12px">TaxID: <b>'+d.txid + '</b></p>';
			if (d.rank > 0){
				tooltip += "<p>rank: "+buttons.nodes[d.rank - 1].name+"</p>";
			}				
			div.transition()
				.duration(200)		
				.style("opacity", .9);		
			div	.html(tooltip)	
				.style("left", (d3.event.pageX) + "px")		
				.style("top", (d3.event.pageY - 28) + "px");	
		})					
	.on("mouseout", function(d) {		
		div.transition()		
			.duration(500)		
			.style("opacity", 0);	
	});
	
  nodeEnter.append("circle")
	  .attr("r", 1e-6)
	  .style("fill", function(d) { 
		if (d.txid.match(/\.\d{2}0$/)){
			return "#fff";
		} else if (d.txid.match(/\.\d{2}1$/)){
			//return "#ff8080";
			return "#99ffbb";
		} else if (d.txid.match(/\.\d{2}2$/)){
			return "lightsteelblue";
		} else if (d.txid.match(/\.\d{2}3$/)){
			return "#ffff99";
		}
	  });
	  
  nodeEnter.append("text")
	  .attr("x", function(d) { return d.children || d._children.length > 0 ? -14 : 14; })
	  .attr("dy", ".35em")
	  //.attr("text-anchor", function(d) { return d.children || d._children.length > 0 ? "end" : "start"; })
	  .text(function(d) { return d.name; })
	  .style("fill-opacity", 1e-6);

  // Transition nodes to their new position.
  var nodeUpdate = node.transition()
	  .duration(duration)
	  .attr("transform", function(d) { return "translate(" + d.y + "," + d.x + ")"; });
	  
  nodeUpdate.select("circle")
	  .attr("r", treeNodeSize)
	  .style("fill", function(d) { 
		if (d.txid.match(/\.\d{2}0$/)){
			return "#fff";
		} else if (d.txid.match(/\.\d{2}1$/)){
			return "#99ffbb";
			//return "#ff8080";
		} else if (d.txid.match(/\.\d{2}2$/)){
			return "lightsteelblue";
		} else if (d.txid.match(/\.\d{2}3$/)){
			return "#ffff99";
		}
	  })
	  .style("stroke-width", function(d){ return d._children.length > 0 ? 6 : 2})
	  .style("stroke", "steelblue");

  nodeUpdate.select("text")
	  .attr("transform", function(d) { return "rotate("+textAngle+")"; })
	  .style("fill-opacity", 1)
	  //.style("font", fontSize+"px sans-serif")
	  .style("font-size", fontSize+"px")
	  .attr("x", 14);
	  //.attr("transform", function(d) { return d.children ?  "rotate(60)": ""; });

  // Transition exiting nodes to the parent's new position.
  var nodeExit = node.exit().transition()
	  .duration(duration)
	  .attr("transform", function(d) { return "translate(" + source.y + "," + source.x + ")"; })
	  .remove();

  nodeExit.select("circle")
	  .attr("r", 1e-6);

  nodeExit.select("text")
	  .style("fill-opacity", 1e-6);

  // Update the links…
  var link = svg.selectAll("path.link")
	  .data(links, function(d) { return d.target.id; });

  // Enter any new links at the parent's previous position.
  link.enter().insert("path", "g")
	  .attr("class", "link")
	  .attr("d", function(d) {
		var o = {x: source.x0, y: source.y0};
		return diagonal({source: o, target: o});
	  })
	  .style("fill", "none")
	  .style("stroke", "#ccc")
	  .style("stroke-width", "2px");

  // Transition links to their new position.
  link.transition()
	  .duration(duration)
	  .attr("d", diagonal);

  // Transition exiting nodes to the parent's new position.
  link.exit().transition()
	  .duration(duration)
	  .attr("d", function(d) {
		var o = {x: source.x, y: source.y};
		return diagonal({source: o, target: o});
	  })
	  .remove();

  // Stash the old positions for transition.
  nodes.forEach(function(d) {
	d.x0 = d.x;
	d.y0 = d.y;
  });
}

// Distinguish between single and double click
var clickedOnce = false;
var timer;

function distinguishClick(d){
/*	var cc = clickcancel();
	console.log(cc);
	cc.on('click', click(d));
	cc.on('dblclick', dblclick(d));*/
	if (d3.event.shiftKey) {
		shiftclick(d);
		return false;
	}
	if (clickedOnce) {
		clearTimeout(timer);
		clickedOnce = false;
		dblclick(d);
	} else {
		timer = setTimeout(function(){click(d)}, 250);
		clickedOnce = true;
	}
}

function taxon(txid, name, rank, comname, unclass){
	this.txid = txid;
	this.rank = rank;
	this.unclass = Number(unclass);
	this.name = name;
	this.comname = comname;
	this.hasChildren = {};
	this.originalParent = {};
	this.children = [];
	this._children = [];
}

function sortChildren (children){
	children.sort(function(a,b) {
		var name1 = name2consider(a.name, a.txid);
		var name2 = name2consider(b.name, b.txid);
		
		function name2consider(name, txid){

			if (txid.match(/\.\d{2}[1-3]$/)){
				var arrayName = name.split("_");
				arrayName.shift();
				if(txid.match(/\.\d{2}1$/)){
					name = arrayName.join("_");
				} else {
					arrayName.shift();
					name = arrayName.join("_");
				}
				
			}
			return name;
		}
		
		if ((a.unclass && b.unclass) || (!a.unclass && !b.unclass)){
			return (name1 > name2) ? 1 : ((name2 > name1) ? -1 : 0);	
		} else {
			return (a.unclass) ? 1 : ((b.unclass) ? -1 : 0);	
		}
		
	
	}); 
	return children;
}
function generateHasChildren (children){
	var hasChildren = {};
	for (var i = 0; i < children.length; i++){
		hasChildren[children[i].txid] = i;
	}
	return hasChildren;
}
// Toggle children on click.
function dblclick(d) {

  if (d.txid) {
  
	var depth = d.depth;
	var countDepth = -1;
	var currentDepth = 0;
	for(var i = 0; i < rankNumber+1; i++){
		if (taxData.rank[i].switch){
			countDepth++;
		}
		if (countDepth == depth){
			currentDepth = i;
			break;
		}
	}
	var childrenDepth = currentDepth;
	for(var i = currentDepth + 1; i < rankNumber+1; i++){
		if (taxData.rank[i].switch){
			childrenDepth = i;
			break;
		}
	}
	if (childrenDepth - currentDepth > 0){
		
		function getchildren(txid, count){
			var countGet = count;
			countGet++;
			
			while(txid.length > 0){
				var txidQuery2 = txid.splice(0,100);
				var txidQuery = txidQuery2.join();
				$.ajax({
					url: "./cgi-bin/taxallnomy_getChildren.pl?txid=" + txidQuery,
				}).done(function (result){
					getchildrenDone(result, countGet)
				});	
			}
			
		}
		
		function getchildrenDone(result,count){
			var countGet = count;
			var depth = currentDepth + 1 + countGet-1;
			var parentTax = [];
			for(var k in result){
				for(var l in result[k].children){
					var newTxid = result[k].children[l].txid;
					parentTax.push(newTxid);
					if (!(result[k].children[l].txid in taxData.leaf)){
						var newName = result[k].children[l].name;
						var comName = result[k].children[l].comname;
						var unclass = result[k].children[l].unclass;
						var newTaxon = new taxon(newTxid, newName, depth, comName, unclass);
						taxData.leaf[newTxid] = newTaxon;
						taxData.leaf[newTxid].originalParent = taxData.leaf[k];
						taxData.rank[depth].taxa.push(newTaxon);
					}
				}
			}
			
			if (parentTax.length > 0){
				if (childrenDepth - currentDepth > countGet){
					getchildren(parentTax, countGet);
				} else {
					if (!d.children){
						if (!d._children){
							d.children = [];
						} else {
							d.children = d._children;
							d._children = [];
						}
					}
					
					//var m = d.children.length;
					for (var k in result){
						for(var l in result[k].children){
							if (!(result[k].children[l].txid in d.hasChildren)){
								if (result[k].children[l].unclass == 1 && hideUnclassified){
									continue;
								} else {
									var newTxid = result[k].children[l].txid;
									d.children.push(taxData.leaf[newTxid]);
									//d.hasChildren[newTxid] = m;
								}
							}
						}
						d.children = sortChildren(d.children);
						d.hasChildren = generateHasChildren(d.children);
					}
					update(d);
				}
			} else {
				return false;
			}
		}
		txid = []
		txid.push(d.txid);
		//var countGet = 0;
		getchildren(txid,0);
	} 	
  }
}

function click(d){
	if (d.children) {
		d._children = d._children.concat(d.children);
		d.children = [];
	} else {
		d.children = d._children;
		d._children = [];
	  }
	  update(d);
	  clickedOnce = false;
}

function shiftclick(d){
	if (!d.parent){ // shift click in root node
		var children = Object.keys(d.hasChildren);
		d.children = [];
		d.hasChildren = {};
		while (children.length > 0){
			var child = children.shift();
			if (Object.keys(taxData.leaf[child].hasChildren).length > 0){
				children = children.concat(Object.keys(taxData.leaf[child].hasChildren));
			}
			delete taxData.leaf[child];
		}
		update(d);
	} else {
	
		var parent = d.parent;
		var rank = d.rank;
		var index = parent.hasChildren[d.txid];
		var txid2delete = d.txid;
		
		parent.children.splice(index,1);
		parent.hasChildren = {};
		parent.hasChildren = generateHasChildren(parent.children);
		var childrenTxid = {};
		childrenTxid[d.txid] = 1;

		var indexes = $.map(taxData.rank[rank].taxa, function(obj, index) {
			if(obj.txid == txid2delete) {
				return index;
			}
		});
		var tax2splice = [indexes[0]];
		for(var i = rank + 1; i < rankNumber+1; i++){
			if (taxData.rank[i].taxa.length > 0 || tax2splice.length > 0){
				var childrenTxid2 = {};
				var tax2splice2 = [];
				for(var j = taxData.rank[i].taxa.length - 1; j >= 0 ; j--){
					if (taxData.rank[i].taxa[j].originalParent.txid in childrenTxid){
						childrenTxid2[taxData.rank[i].taxa[j].txid] = 1;
						delete taxData.leaf[taxData.rank[i].taxa[j].txid];
						tax2splice2.push(j);
					}
				}
				for(var j = 0; j < tax2splice.length; j++){
					delete taxData.leaf[taxData.rank[i-1].taxa[tax2splice[j]].txid];
					taxData.rank[i-1].taxa.splice(tax2splice[j], 1);
				}
				tax2splice = tax2splice2;
				if (Object.keys(childrenTxid2).length > 0){
					childrenTxid = childrenTxid2;
				} else {
					break;
				}
			} else {
				break;
			}
		}
		if (tax2splice.length > 0){
			for(var j = 0; j < tax2splice.length; j++){
				taxData.rank[rankNumber].taxa.splice(tax2splice[j], 1);
			}
		}
		update(d.parent);
	}
	
	return false;
}

function zoom(d) {
	var scale = d3.event.scale,
		translation = d3.event.translate;
/*        translation = d3.event.translate,
		tbound = -height * scale,
		bbound = height * scale,
		lbound = (-width + margin.right) * scale,
		rbound = (width - margin.left) * scale;
	// limit translation to thresholds*/
	translation = [
		translation[0] + margin.right,
		translation[1] + height/2
	];
	d3.select("g")
		.attr("transform", "translate(" + translation + ")" +
			  " scale(" + scale + ")");
}


function zoomButton(d) { // https://bl.ocks.org/mbostock/7ec977c95910dd026812

  svg.call(zooming.event); // https://github.com/mbostock/d3/issues/2387

  // Record the coordinates (in data space) of the center (in screen space).
  var center0 = zooming.center(), translate0 = zooming.translate(), coordinates0 = coordinates(center0);
  zooming.scale(zooming.scale() * Math.pow(1.25, +d));

  // Translate back to the center.
  var center1 = point(coordinates0);
  zooming.translate([translate0[0] + center0[0] - center1[0], translate0[1] + center0[1] - center1[1]]);

  svg.transition().duration(350).call(zooming.event);
}

function coordinates(point) { // https://bl.ocks.org/mbostock/7ec977c95910dd026812
  var scale = zooming.scale(), translate = zooming.translate();
  return [(point[0] - translate[0]) / scale, (point[1] - translate[1]) / scale];
}

function point(coordinates) { // https://bl.ocks.org/mbostock/7ec977c95910dd026812
  var scale = zooming.scale(), translate = zooming.translate();
  return [coordinates[0] * scale + translate[0], coordinates[1] * scale + translate[1]];
}


function collapseRank(rank){
	if (taxData.rank[rank].switch){
		var parentRank = 0;
		for (var k = rank - 1; k >= 0; k--){
			if (taxData.rank[k].switch){
				parentRank = k;
				break;
			}
		}
		
		if (taxData.rank[rank].taxa.length > 0){
			
			// change parent children to the children of the next rank
			for (var i = 0; i < taxData.rank[parentRank].taxa.length; i++){
				// pick children of children
				var childrenOfChildren = [];
				var _childrenOfChildren = [];
				var children = [];
				if (taxData.rank[parentRank].taxa[i].children){
					children = taxData.rank[parentRank].taxa[i].children;
				}
				taxData.rank[parentRank].taxa[i].hasChildren = {};
				children = children.concat(taxData.rank[parentRank].taxa[i]._children);
				if (children.length > 0){
					
					for (var j = 0; j < children.length; j++){
						if (children[j].children){
							if (children[j].children.length > 0){
								childrenOfChildren = childrenOfChildren.concat(children[j].children);
							}
						}
						if (children[j]._children.length > 0){
							_childrenOfChildren = _childrenOfChildren.concat(children[j]._children);
						}
					}
					taxData.rank[parentRank].taxa[i].children = sortChildren(childrenOfChildren);
					taxData.rank[parentRank].taxa[i].hasChildren = generateHasChildren(taxData.rank[parentRank].taxa[i].children);
					taxData.rank[parentRank].taxa[i]._children = _childrenOfChildren;
					for (var j = 0; j < _childrenOfChildren.length; j++){
						taxData.rank[parentRank].taxa[i].hasChildren[_childrenOfChildren[j].txid] = j + childrenOfChildren.length;
					}
				}
			}
		}
		taxData.rank[rank].switch = 0;
		//update(root);
	}
}

function uncollapseRank(rank){
	rank = Number(rank);
	if (!taxData.rank[rank].switch){
		var parentRank = 0;
		for (var i = rank - 1; rank >= 0; i--){
			if (taxData.rank[i].switch){
				parentRank = i;
				break;
			}
		}
		var childRank = 0;
		for (var i = rank + 1; i < rankNumber+1; i++){
			if (taxData.rank[i].switch){
				childRank = i;
				break;
			}
		}
		
		// reset parent children array
		var parentTaxa = {};
		for (var i = 0; i < taxData.rank[parentRank].taxa.length; i++){
			//if (taxData.rank[parentRank].taxa[i].children){
				taxData.rank[parentRank].taxa[i].children = [];
				taxData.rank[parentRank].taxa[i]._children = [];
				taxData.rank[parentRank].taxa[i].hasChildren = {};
			//}
			parentTaxa[taxData.rank[parentRank].taxa[i].txid] = 1;
		}
		
		// populate parent children array and reset current rank taxa children array
		var currentTaxa = {};
		var taxon2analyse = sortChildren(taxData.rank[rank].taxa);
		//var taxon2splice = [];
		//var countSplice = 0;
		for (var i = 0; i < taxon2analyse.length; i++){
			
			/*if (!taxData.leaf[taxon2analyse[i].txid]){
				taxon2splice.push(i);
				countSplice++;
				continue;
			}*/
			var taxon = taxon2analyse[i];
			if (taxon.children){
				taxon.children = [];
			}
			taxon._children = [];
			currentTaxa[taxon.txid] = 1;
			var parentData = taxon.originalParent;
			//parentData.hasChildren = {};
			while (!parentTaxa[parentData.txid]){
				taxon = parentData;
				parentData = taxon.originalParent;
			}
			parentData.children.push(taxon2analyse[i]);
			parentData.hasChildren[taxon2analyse[i].txid] = parentData.children.length - 1;
		}

		/*taxon2splice = taxon2splice.sort().reverse();
		for (var i = 0; i < taxon2splice.length; i++){
			taxData.rank[rank].taxa.splice(taxon2splice[i], 1);
		}*/
		
		// populate children children array
		if (childRank){
			taxon2analyse = sortChildren(taxData.rank[childRank].taxa);
			//taxon2splice = [];
			//countSplice = 0;
			for (var i = 0; i < taxon2analyse.length; i++){
				/*if (!taxData.leaf[taxon2analyse[i].txid]){
					taxon2splice.push(i);
					countSplice++;
					continue;
				}*/
				var taxon = taxon2analyse[i];
				var parentData = taxon.originalParent;
				//parentData.hasChildren = {};
				while (!currentTaxa[parentData.txid]){
					taxon = parentData;
					parentData = taxon.originalParent;
				}
				if (!parentData.children){
					parentData.children = [];
				}
				parentData.children.push(taxon2analyse[i]);
				parentData.hasChildren[taxon2analyse[i].txid] = parentData.children.length - 1;
			}
			
			/*taxon2splice = taxon2splice.sort().reverse();
			for (var i = 0; i < taxon2splice.length; i++){
				taxData.rank[childRank].taxa.splice(taxon2splice[i], 1);
			}*/
		}
		
		taxData.rank[rank].switch = 1;
		//update(root);
	}
}

function toggleUnclassified (){
	if (hideUnclassified){
		uncollapseUnclassified();
		hideUnclassified = false;
	} else {
		collapseUnclassified();
		hideUnclassified = true;
	}
	update(root);
}

function collapseUnclassified(){
	for (var taxon2 in taxData.leaf){
		if (taxData.leaf[taxon2].unclass){
			var d = taxData.leaf[taxon2];
			var parent = d.parent;
			var rank = d.rank;
			if (taxData.rank[rank].switch){
				var index = parent.hasChildren[d.txid];
				var txid2delete = d.txid;
				
				parent.children.splice(index,1);
				parent.hasChildren = {};
				parent.hasChildren = generateHasChildren(parent.children);
			} else {
				continue;
			}
		} else {
			continue;
		}
	}
}

function uncollapseUnclassified(){
	for (var taxon2 in taxData.leaf){
		if (taxData.leaf[taxon2].unclass){
			var rank = taxData.leaf[taxon2].rank;
			if (taxData.rank[rank].switch){
				var parentRank = 0;
				for (var k = rank - 1; k >= 0; k--){
					if (taxData.rank[k].switch){
						parentRank = k;
						break;
					}
				}
				var parentData = taxData.leaf[taxon2].originalParent;
				//parentData.hasChildren = {};
				while (parentData.rank != parentRank){
					parentData = parentData.originalParent;
				}
				if (!parentData.children){
					parentData.children = [];
				}
				parentData.children.push(taxData.leaf[taxon2]);
				parentData.hasChildren[taxData.leaf[taxon2].txid] = parentData.children.length - 1;
			} else {
				continue;
			}
			
		} else {
			continue;
		}
	}
}