import * as React from "react"
import * as ReactDOM from "react-dom"
import StageHeader from "./components/StageHeader"
import FormikConjure from "./components/FormikConjure"
import { TreeContainer } from "./components/TreeContainer"
import { Check } from "./components/Check"
import { Cache, RepMap } from "../configHelper"
import { cloneDeep } from "lodash"
import SplitPane from "react-split-pane"
import { Wrapper } from "./components/Constants"

import "./styles.css"

if (process.env.NODE_ENV !== "production") {
  const whyDidYouRender = require("@welldone-software/why-did-you-render/dist/no-classes-transpile/umd/whyDidYouRender.min.js")
  whyDidYouRender(React)
}

interface State {
  // core: Core | undefined;
  trees: any
  isCollapsed: boolean
  diff: boolean
  allCaches: Cache[]
  selectedCaches?: (Cache | undefined)[]
  essenceFiles: string[]
  paramFiles: string[]
  reps: RepMap
  nimServerPort: number
  vscodeServerPort: number
}

class F extends React.Component<any, State> {
  // static whyDidYouRender = true;

  constructor(props: any) {
    super(props)
    this.state = {
      trees: undefined,
      isCollapsed: false,
      diff: false,
      allCaches: [],
      paramFiles: [],
      essenceFiles: [],
      reps: {},
      nimServerPort: 5000,
      vscodeServerPort: Number(
        document.getElementById("port")!.getAttribute("vscodeserverport")
      )
    }
    console.log("hello")
  }

  collapseHandler = () => {
    this.setState((prevState: State) => {
      return { isCollapsed: !prevState.isCollapsed }
    })
  }

  initResponseHandler = (data: any) => {
    this.setState({
      isCollapsed: true,
      trees: data.trees,
      nimServerPort: data.nimServerPort
    })
    this.getFiles()
    console.log("The data from the vscodeserver")
    console.log(data)
  }

  cacheChangeHandler = (cache: Cache, index: number) => {
    this.setState((prevState: State) => {
      let copy = cloneDeep(prevState.selectedCaches)
      if (!copy) {
        return { selectedCaches: [{ ...cache }, undefined] }
      }
      copy[index] = cache
      return { selectedCaches: copy }
    })
  }

  clickHandler = () => {
    this.setState((prevState: State) => {
      return { diff: !prevState.diff }
    })
  }

  getFiles = async () => {
    await fetch(`http://localhost:${this.state.vscodeServerPort}/config/files`)
      .then(response => response.json())
      .then(data => {
        this.setState({
          paramFiles: data.params,
          essenceFiles: data.models,
          reps: data.representations
        })
        return
      })
      .then(() => {
        fetch(`http://localhost:${this.state.vscodeServerPort}/config/caches`)
          .then(response => response.json())
          .then(data => {
            this.setState({
              allCaches: data
            })
            // console.log("fromServer", data)
          })
      })
  }

  componentDidMount = () => {
    this.getFiles()
  }

  render = () => {
    const testCore = {
      nodes: [
        {
          id: 0,
          parentId: -1,
          label: "",
          prettyLabel: "",
          childCount: 1,
          isSolution: false,
          isLeftChild: true,
          descCount: 32
        },
        {
          id: 1,
          parentId: 0,
          label: "Root Propagation",
          prettyLabel: "Root Propagation",
          childCount: 1,
          isSolution: false,
          isLeftChild: true,
          descCount: 31
        },
        {
          id: 2,
          parentId: 1,
          label: "setA_Occurrence_00001 = 0",
          prettyLabel: "1 was excluded from setA",
          childCount: 2,
          isSolution: false,
          isLeftChild: true,
          descCount: 30
        },
        {
          id: 16,
          parentId: 2,
          label: "setA_Occurrence_00002 != 0",
          prettyLabel: "2 was included in setA",
          childCount: 2,
          isSolution: false,
          isLeftChild: false,
          descCount: 16
        },
        {
          id: 26,
          parentId: 16,
          label: "setA_Occurrence_00003 != 0",
          prettyLabel: "3 was included in setA",
          childCount: 1,
          isSolution: false,
          isLeftChild: false,
          descCount: 6
        },
        {
          id: 27,
          parentId: 26,
          label: "setA_Occurrence_00004 = 0",
          prettyLabel: "4 was excluded from setA",
          childCount: 2,
          isSolution: false,
          isLeftChild: true,
          descCount: 5
        },
        {
          id: 30,
          parentId: 27,
          label: "setA_Occurrence_00005 != 0",
          prettyLabel: "5 was included in setA",
          childCount: 1,
          isSolution: false,
          isLeftChild: false,
          descCount: 2
        },
        {
          id: 31,
          parentId: 30,
          label: "setA_Occurrence_00006 = 0",
          prettyLabel: "6 was excluded from setA",
          childCount: 1,
          isSolution: false,
          isLeftChild: true,
          descCount: 1
        },
        {
          id: 32,
          parentId: 31,
          label: "setA_Occurrence_00007 = 0",
          prettyLabel: "7 was excluded from setA",
          childCount: 0,
          isSolution: true,
          isLeftChild: true,
          descCount: 0
        },
        {
          id: 3,
          parentId: 2,
          label: "setA_Occurrence_00002 = 0",
          prettyLabel: "2 was excluded from setA",
          childCount: 2,
          isSolution: false,
          isLeftChild: true,
          descCount: 12
        },
        {
          id: 17,
          parentId: 16,
          label: "setA_Occurrence_00003 = 0",
          prettyLabel: "3 was excluded from setA",
          childCount: 2,
          isSolution: false,
          isLeftChild: true,
          descCount: 8
        },
        {
          id: 28,
          parentId: 27,
          label: "setA_Occurrence_00005 = 0",
          prettyLabel: "5 was excluded from setA",
          childCount: 1,
          isSolution: false,
          isLeftChild: true,
          descCount: 1
        }
      ],
      solAncestorIds: [0, 1, 2, 16, 26, 27, 30, 31, 32],
      id: "blah"
    }

    const fiveNodes = {
      nodes: [
        {
          id: 0,
          parentId: -1,
          label: "",
          prettyLabel: "",
          childCount: 2,
          isSolution: false,
          isLeftChild: true,
          descCount: 4
        },
        {
          id: 1,
          parentId: 0,
          label: "Root Propagation",
          prettyLabel: "Root Propagation",
          childCount: 1,
          isSolution: false,
          isLeftChild: true,
          descCount: 1
        },
        {
          id: 3,
          parentId: 0,
          label: "setA_Occurrence_00001 = 0",
          prettyLabel: "1 was excluded from setA",
          childCount: 1,
          isSolution: false,
          isLeftChild: false,
          descCount: 1
        },
        {
          id: 2,
          parentId: 1,
          label: "setA_Occurrence_00001 = 0",
          prettyLabel: "1 was excluded from setA",
          childCount: 0,
          isSolution: false,
          isLeftChild: false,
          descCount: 0
        },
        {
          id: 4,
          parentId: 3,
          label: "setA_Occurrence_00001 = 0",
          prettyLabel: "1 was excluded from setA",
          childCount: 0,
          isSolution: false,
          isLeftChild: true,
          descCount: 0
        }
      ],
      id: "poop",
      solAncestorIds: [0, 2]
    }

    if (this.state.trees) {
      console.log(true)
    }
    return (
      <div>
        <StageHeader
          title={"Setup"}
          id={"setup"}
          isCollapsed={this.state.isCollapsed}
          // isCollapsed={true}
          collapseHandler={this.collapseHandler}
        >
          <Check
            title={"Do two diffs"}
            checked={this.state.diff}
            onChange={this.clickHandler}
          />

          <button
            className="btn btn-danger btn-lg btn-block"
            onClick={async () => {
              console.log("Should invalidate caches!")
              await fetch(
                `http://localhost:${this.state.vscodeServerPort}/config/invalidateCaches`
              )
              await this.getFiles()
              console.log("Done!!")
            }}
          >
            Invalidate Caches
          </button>

          <FormikConjure
            vscodeServerPort={this.state.vscodeServerPort}
            reps={this.state.reps}
            responseHandler={this.initResponseHandler}
            diff={this.state.diff}
            selectedCaches={this.state.selectedCaches}
            paramFiles={this.state.paramFiles}
            essenceFiles={this.state.essenceFiles}
            cacheChangeHandler={this.cacheChangeHandler}
            caches={this.state.allCaches}
          />
        </StageHeader>

        <div className="">
          <Wrapper>
            {this.state.trees &&
              this.state.trees.map((tree: any, i: number) => (
                <TreeContainer
                  key={this.state.trees[i].path}
                  path={this.state.trees[i].path}
                  nimServerPort={this.state.nimServerPort}
                  info={this.state.trees[i].info}
                  core={this.state.trees[i].core}
                  identifier={`tree${i}`}
                />
              ))}
            )}
          </Wrapper>
        </div>
        {/* <TreeContainer info={"blah"} identifier={"letree"} core={testCore} /> */}
      </div>
    )
  }
}

ReactDOM.render(
  // <FormikApp email="barrybil@brownmail"/>,
  <div>
    <F />
    {/* <FormikConjure diff={true}/> */}
  </div>,
  document.getElementById("root")
)
