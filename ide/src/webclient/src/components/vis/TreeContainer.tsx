import * as React from 'react'
import * as ReactDOM from 'react-dom'
import Node from '../../modules/Node'
import TreeVis from './TreeVis'
import StatsBar from './StatsBar'
import { HotKeys } from 'react-hotkeys'
import { cloneDeep, last, min, max } from 'lodash'
import * as d3 from 'd3'
import { Domains } from './Domains'
import SplitPane from 'react-split-pane'
import { Wrapper } from '../common/Constants'
import { Check } from '../common/Check'
import * as TreeHelper from '../../modules/TreeHelper'
import * as MovementHelper from '../../modules/MovementHelper'

export interface FromServerNode {
	id: number
	parentId: number
	label: string
	prettyLabel: string
	childCount: number
	isSolution: boolean
	isLeftChild: boolean
	descCount: number
	// isLeftTree: boolean
}

export type MyMap = Record<number, Node>

export interface Core {
	nodes: FromServerNode[]
	solAncestorIds: number[]
}

interface Props {
	selected: number
	identifier: string
	core: Core
	info: string
	path: string
	hash: string
	nimServerPort: number
	playing: boolean
	reverse: boolean
	showLabels: boolean
	loadDepth: number
	duration: number
	interval: number
	finishedPlayingHandler: () => void
	collapseAsExploring: boolean
	diffParentId: number
	requestHandler: (url: string, payload: any, isNimServer: boolean) => any
}

export interface State {
	id2Node: MyMap
	solveable: boolean
	selected: number
	linScale: any
	minsize: number
	shouldGetKids: boolean
	solNodeIds: number[]
	totalNodeCount: number
	failedBranchCount: number
}

export class TreeContainer extends React.Component<Props, State> {
	// static whyDidYouRender = true;

	map = {
		goLeft: [ 'left', 's', 'a', 'down' ],
		goRight: [ 'right', 'd' ],
		goUp: [ 'up', 'w' ],
		collapse: 'c',
		expand: 'e',
		pPressed: 'p',
		goToRoot: 'r',
		goPrev: 'shift',
		showCore: 'f',
	}

	handlers: any

	constructor(props: Props) {
		super(props)
		this.state = TreeHelper.makeState(props.core, props.selected)

		this.handlers = {
			goLeft: () => MovementHelper.goLeft(this),
			goUp: () => MovementHelper.goUp(this),
			goRight: () => MovementHelper.goRight(this),
			goToRoot: () => this.setState({ selected: 0 }),
			goPrev: () => MovementHelper.goToPreviousHandler(this),
			collapse: this.collapse,
			expand: this.expand,
			showCore: this.showCore,
		}
	}

	nodeClickHandler = (d: Node) => {
		this.setState({ selected: d.id })
	}

	showCore = () => {
		console.log('Show core pressed!')

		this.setState((prevState: State) => {
			let newMap = cloneDeep(prevState.id2Node)

			this.props.core.solAncestorIds.forEach((nodeId: number) => {
				let current = newMap[nodeId]

				if (!current.children) {
					return
				}
				current.children.forEach((child: Node) => {
					if (!this.props.core.solAncestorIds.includes(child.id)) {
						Node.collapseNode(child)
					}
				})
			})

			let selected = this.state.selected

			if (!this.props.core.solAncestorIds.includes(selected)) {
				selected = max(this.props.core.solAncestorIds.filter((id) => id < selected))!
			}

			return { id2Node: newMap, selected: selected }
		})
	}

	collapse = () => {
		this.setState((prevState: State) => {
			const toCollapse = prevState.selected

			let newMap = cloneDeep(prevState.id2Node)
			Node.collapseNode(newMap[toCollapse])
			// Node.hideChildren(newMap[toCollapse])
			return { id2Node: newMap }
		})
	}

	expand = () => {
		this.setState((prevState: State) => {
			const toExpand = prevState.selected
			let newMap = cloneDeep(prevState.id2Node)
			Node.expandNode(newMap[toExpand])
			// Node.showChildren(newMap[toExpand])
			return { id2Node: newMap }
		})
	}

	play = async () => {
		while (this.props.playing) {
			if (
				(this.state.selected === last(this.props.core.solAncestorIds)! && !this.props.reverse) ||
				(this.state.selected === 0 && this.props.reverse)
			) {
				break
			}
			if (this.props.reverse) {
				MovementHelper.goToPreviousHandler(this)
			} else {
				MovementHelper.goLeft(this)
			}
			await TreeHelper.sleep(this.props.interval)
		}
		this.props.finishedPlayingHandler()
	}

	componentDidUpdate = (prevProps: Props) => {
		// Typical usage (don't forget to compare props):

		console.log(prevProps.hash)
		console.log(this.props.hash)
		console.log('~~~~~~~~~')

		if (this.props.hash !== prevProps.hash) {
			this.setState(TreeHelper.makeState(this.props.core, this.props.selected))
		}

		if (this.props.playing !== prevProps.playing) {
			this.play()
		}

		if (this.props.selected !== prevProps.selected) {
			MovementHelper.loadAncestors(this.props.selected, this)
		}
	}

	render = () => {
		return (
			<HotKeys keyMap={this.map} handlers={this.handlers}>
				<StatsBar
					info={this.props.info}
					nextSolBranchHandler={() => MovementHelper.nextSolBranch(this)}
					prevSolBranchHandler={() => MovementHelper.prevSolBranch(this)}
					nextNodeHandler={() => MovementHelper.goLeft(this)}
					prevNodeHandler={() => MovementHelper.goToPreviousHandler(this)}
					nextFailedHandler={() => MovementHelper.nextFailed(this)}
					prevFailedHandler={() => MovementHelper.prevFailed(this)}
					nextSolHandler={() => MovementHelper.nextSol(this)}
					prevSolHandler={() => MovementHelper.prevSol(this)}
					minsize={this.state.minsize}
					solNodeIds={this.state.solNodeIds}
					totalNodes={this.state.totalNodeCount}
					failedBranchCount={this.state.failedBranchCount}
					linScale={this.state.linScale}
				/>

				<Wrapper>
					<SplitPane split='horizontal' defaultSize={700} maxSize={900}>
						<TreeVis
							hash={this.props.hash}
							identifier={this.props.identifier}
							rootNode={this.state.id2Node[0]}
							selected={this.state.selected}
							solAncestorIds={this.props.core.solAncestorIds}
							solveable={this.state.solveable}
							linScale={this.state.linScale}
							minsize={this.state.minsize}
							nodeClickHandler={this.nodeClickHandler}
							storeNodePrevPos={(list) => {
								this.setState((prevState: State) => {
									let newMap = cloneDeep(prevState.id2Node)
									list.forEach((d) => {
										newMap[d.data.id].x0 = d.x
										newMap[d.data.id].y0 = d.y
									})
									console.log('CALLED')
									// console.log(newMap[28])
									return { id2Node: newMap }
								})
							}}
							duration={this.props.duration}
							width={1200}
							height={500}
							showLabels={this.props.showLabels}
							diffParentId={this.props.diffParentId}
						/>

						<Domains
							hash={this.props.hash}
							selected={this.state.selected}
							path={this.props.path}
							nimServerPort={this.props.nimServerPort}
						/>
						<h1>DASDASDASDAS</h1>
					</SplitPane>
				</Wrapper>
			</HotKeys>
		)
	}
}
