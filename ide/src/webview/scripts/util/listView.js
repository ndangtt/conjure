import colours from './colours.js';
import "./treelist"
import globals from "./globals"

let panel = jsPanel.create({
    theme: colours.bgColour + ' filled',
    headerTitle: 'my panel #1',
    position: 'right-top 0 58',
    contentSize: {
        // width: 450,
        width: () => {
            return $(document).width() / 3;
        },
        height: () => {
            return $(document).height() * 0.9;
        }
    },
    content: `
    <div id="pane"> </div>`
});

export function setNodeId(){
    panel.setHeaderTitle("Node: " + globals.selectedId);
}

var id = 0;
var tree = d3.layout.treelist()
.childIndent(15)
.nodeHeight(40);

var init = true;
var rootNode;

var name2Node = {}

var changedList;

var ul;

export function createUL(){
    init = true;
    ul = d3.select("#pane").append("ul").classed("treelist", "true");
}

export function getRootNode(){
    return rootNode;
}

export function updateNodes(data) {


    data.forEach(element => {

        // console.log(name2Node[element.name].children[0].name);

        // Chec if its a set
        if (element.Cardinality) {
            name2Node[element.name].children[1].children[0].name = element.Cardinality
            name2Node[element.name].children[2].children[0].name = element.Included
            name2Node[element.name].children[3].children[0].name = element.Excluded
        }
        else {
            name2Node[element.name].children[0].name = element.rng;
        }

    });

    render(rootNode, rootNode);
}

export function setChangedList(list) {
    changedList = list
}

export function setChanged() {
    d3.selectAll("li").classed("changed", false);

    changedList.forEach(element => {

        d3.select('[id="' + element + '"]').classed("changed", true);
        // console.log(d3.select('[id="' + element + '"]' ).classed("changed"));

    });
}

export function render(data, parent) {

    if (globals.selectedId === 1 && !init){
        return; 
    }
    // console.log("CALLED RENDER");

    if (init) {
        init = false;
        rootNode = data;
    }

    var nodes = tree.nodes(data),
        duration = 250;

    function toggleChildren(d) {
        if (d.children) {
            d._children = d.children;
            d.children = null;
        } else if (d._children) {
            d.children = d._children;
            d._children = null;
        }
    }

    var nodeEls = ul.selectAll("li.node").data(nodes, function (d) {
        d.id = d.id || ++id;
        return d.id;
    });
    //entered nodes
    var entered = nodeEls.enter().append("li").classed("node", true)
        .attr("id", (d) => {

            let parentName = "";

            if (d.parent) {
                parentName = d.parent.name;
            }

            return "li" + parentName + d.name;
        })
        .style("top", parent.y + "px")
        .style("opacity", 0)
        .style("height", tree.nodeHeight() + "px")
        .on("click", function (d) {
            toggleChildren(d);
            render(data, d);
            setChanged();

        })
        .on("mouseover", function (d) {
            // d3.select(this).classed("changed", true);
        })
        .on("mouseout", function (d) {
            // d3.selectAll(".changed").classed("changed", false);
        })
        .each((d) => {
            name2Node[d.name] = d;
        })
    //add arrows if it is a folder
    entered.append("span").attr("class", function (d) {
        var icon = d.children ? "fas fa-chevron-down"
            : d._children ? "fas fa-chevron-right" : "";
        return "caret " + icon;
    });
    //add icons for folder for file
    // entered.append("span").attr("class", function (d) {
    //     var icon = d.children || d._children ? "glyphicon-folder-close"
    //         : "glyphicon-file";
    //     return  icon;
    // });
    //add text
    entered.append("span").attr("class", "filename")
        .html(function (d) { return d.name; });


    //  update the ranges

    d3.selectAll("span.filename").html((d) => {
        // console.log("D is  " + d.name);

        return d.name;


    })


    //update caret direction
    nodeEls.select("span.caret").attr("class", function (d) {
        var icon = d.children ? "fas fa-chevron-down"
            : d._children ? "fas fa-chevron-right" : "";
        return "caret " + icon;
    });
    //update position with transition
    nodeEls.transition().duration(duration)
        .style("top", function (d) { return (d.y - tree.nodeHeight()) + "px"; })
        .style("left", function (d) { return d.x + "px"; })
        .style("opacity", 1);
    nodeEls.exit().remove();

}


createUL();

// let data = {name: "doggo", _children: [{name: "dasdasda", _children : []}]};
// render(data, data);
// console.log("RENDERING")
