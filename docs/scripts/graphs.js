// ************** Generate graphs *****************

dataLine = [];
dataStack = [];
ranks = [];
for(var rank in rankData){
	var order = rankData[rank].order;
	dataLine[order - 1] = [];
	dataStack[order - 1] = [];
	ranks[order - 1] = rank;
	dataStack[order - 1].rank = rank;
	dataStack[order - 1].count_ncbi = Number(rankData[rank].count_ncbi);
	dataStack[order - 1].count_type1 = Number(rankData[rank].count_type1);
	dataStack[order - 1].count_type2 = Number(rankData[rank].count_type2);
	dataStack[order - 1].count_type3 = Number(rankData[rank].count_type3);
	
	dataLine[order - 1].rank = rank;
	dataLine[order - 1].dcount_ncbi = Number(rankData[rank].dcount_ncbi);
	dataLine[order - 1].dcount_taxallnomy = Number(rankData[rank].dcount_ncbi);
	dataLine[order - 1].dcount_taxallnomy += Number(rankData[rank].dcount_type1);
	dataLine[order - 1].dcount_taxallnomy += Number(rankData[rank].dcount_type2);
	dataLine[order - 1].dcount_taxallnomy += Number(rankData[rank].dcount_type3);
}
console.log(dataLine);
// based on http://bl.ocks.org/d3noob/13a36f70a4f060b97e41

// Set the dimensions of the canvas / graph
var margin2 = {top: 30, right: 30, bottom: 30, left: 100},
	width = 600 - margin2.left - margin2.right,
	height = 370 - margin2.top - margin2.bottom;

// Set the ranges
var x = d3.scale.ordinal().rangePoints([0, width]);
var y = d3.scale.log().range([height, 0]);

// Define the axes
var xAxis = d3.svg.axis().scale(x)
	.orient("bottom").ticks(5);

var yAxis = d3.svg.axis().scale(y)
	.orient("left").ticks(5);

// Define the line
var valueline = d3.svg.line()
	.x(function(d) { return x(d.rank); })
	.y(function(d) { return y(d.dcount_ncbi); });
	
// Adds the svg canvas
var svg = d3.select("#numbersLine")
//	.attr("width", width + margin2.left + margin2.right)
//	.attr("height", height + margin2.top + margin2.bottom)
	.append("g")
		.attr("transform", 
			  "translate(" + margin2.left + "," + margin2.top + ")");

// Scale the range of the data
x.domain(ranks);
y.domain([1, d3.max(dataLine, function(d) { return d.dcount_ncbi; })]);

// Add the valueline path.
svg.append("path")
	.attr("fill", "none")
	.attr("stroke", "steelblue")
	.attr("stroke-linejoin", "round")
	.attr("stroke-linecap", "round")
	.attr("stroke-width", 1.5)
	.attr("d", valueline(dataLine));

// Add the X Axis
svg.append("g")
	.attr("class", "x axis")
	.attr("transform", "translate(0," + height + ")")
	.call(xAxis)
  .selectAll("text")
	.attr("y", 0)
	.attr("x", 9)
	.attr("dy", ".35em")
	.attr("transform", "rotate(70)")
	.style("text-anchor", "start");
	
// Add the Y Axis
svg.append("g")
	.attr("class", "y axis")
	.call(yAxis);

