import React from "react"
import {
  render,
  fireEvent,
  waitForElement,
  queryByLabelText,
  getByTestId,
  cleanup,
  RenderResult,
  wait,
  queryByText,
  queryByTestId,
  prettyDOM
} from "@testing-library/react"
import "@testing-library/jest-dom/extend-expect"
import { ConfigForm } from "../src/components/config/ConfigForm"
import { RepMap, newCache } from "../../extension/src/utils"
import { ConjureConfig } from "../src/components/config/ConjureStage"
import { SRConfig } from "../src/components/config/SRStage"
import { MinionConfig } from "../src/components/config/MinionStage"

describe("Test the configure element", () => {
  afterEach(cleanup)

  const findAllCache = newCache()
  findAllCache.name = "16all"
  findAllCache.config.minionConfig.minionSwitches = ["-findallsols"]
  findAllCache.essenceFile = "PartitionProblem.essence"
  findAllCache.paramFile = "16.param"

  const varReps = [
    {
      name: "setA",
      representations: [
        { answer: "setA:1", description: "occurrence" },
        { answer: "setA:2", description: "explicit" }
      ]
    },
    {
      name: "setB",
      representations: [
        { answer: "setB:1", description: "occurrence" },
        { answer: "setB:2", description: "explicit" }
      ]
    }
  ]

  let essenceFileToReps: RepMap = {}
  const essenceFile = "blah.essence"
  const paramFile = "p.param"

  essenceFileToReps[essenceFile] = varReps

  let rendered: RenderResult

  const mockHandler = jest.fn(values => {
    console.log("mock handler called!")
    return values
    // return
  })

  beforeEach(() => {
    cleanup()

    rendered = render(
      <ConfigForm
        caches={[]}
        waiting={false}
        modelToReps={essenceFileToReps}
        essenceFiles={[essenceFile]}
        paramFiles={[paramFile]}
        submitHandler={mockHandler}
      />
    )
  })
  
  afterEach(cleanup)

  test("Solve button is displayed", () => {
    expect(rendered.queryByText("Solve")).toBeTruthy()
    expect(rendered.queryByTestId("spinner")).toBeFalsy()
  })

  test("Click diff check", async () => {
    expect(rendered.queryByText("Config 2")).toBeFalsy()

    fireEvent.click(rendered.getByText("Compare trees"))
    await wait(() => {})

    expect(rendered.queryByText("Config 1")).toBeTruthy()
    expect(rendered.queryByText("Config 2")).toBeTruthy()
  })

  test("Click Solve button", async () => {
    const conjureTime = "1234"
    fireEvent.change(rendered.queryByLabelText("Time limit")!, {
      target: { value: conjureTime }
    })

    const strategy = "s"
    fireEvent.change(rendered.queryByLabelText("Strategy")!, {
      target: { value: strategy }
    })

    const optimisation = "-O3"
    fireEvent.change(rendered.queryByLabelText("Optimisation")!, {
      target: { value: optimisation }
    })

    const translation = "-no-cse"
    fireEvent.change(rendered.queryByLabelText("Translation")!, {
      target: { value: translation }
    })

    const cnf = "11"
    fireEvent.change(rendered.queryByLabelText("CNF clause limit")!, {
      target: { value: cnf }
    })

    fireEvent.click(rendered.getByText("Find all solutions"))

    const solLimit = "213"
    fireEvent.change(rendered.queryByLabelText("Solution limit")!, {
      target: { value: solLimit }
    })

    const consistency = "SSAC"
    fireEvent.change(rendered.queryByLabelText("Consistency")!, {
      target: { value: consistency }
    })

    fireEvent.click(rendered.getByText("Solve"))
    await wait(() => {})
    expect(mockHandler.mock.calls.length).toEqual(1)
    const values = mockHandler.mock.results[0].value
    const conjureConfig: ConjureConfig = values.caches[0].config.conjureConfig
    const srConfig: SRConfig = values.caches[0].config.srConfig
    const minionConfig: MinionConfig = values.caches[0].config.minionConfig

    expect(conjureConfig.conjureTime).toEqual(conjureTime)
    expect(conjureConfig.strategy).toEqual(strategy)

    expect(srConfig.optimisation).toEqual(optimisation)
    expect(srConfig.translation).toEqual(translation)
    expect(srConfig.cnfLimit).toEqual(cnf)

    expect(minionConfig.minionSwitches).toContain("-findallsols")
    expect(minionConfig.solLimit).toEqual(solLimit)
    expect(minionConfig.consistency).toEqual(consistency)
  })

  test("Validation non numeric", async () => {
    const conjureTime = "abc"
    fireEvent.change(rendered.queryByLabelText("Time limit")!, {
      target: { value: conjureTime }
    })

    await wait(() => {})
    expect(rendered.queryByText("Solve")).toBeFalsy()
    expect(
      rendered.getByText("Leave empty or specify an integer > 0")
    ).toBeTruthy()
  })

  test("Validation zero", async () => {
    const conjureTime = "0"
    fireEvent.change(rendered.queryByLabelText("Time limit")!, {
      target: { value: conjureTime }
    })

    await wait(() => {})
    expect(rendered.queryByText("Solve")).toBeFalsy()
    expect(
      rendered.getByText("Leave empty or specify an integer > 0")
    ).toBeTruthy()
  })

  test("Validation no problem", async () => {
    const conjureTime = "1"
    fireEvent.change(rendered.queryByLabelText("Time limit")!, {
      target: { value: conjureTime }
    })

    await wait(() => {})
    expect(
      rendered.queryByText("Leave empty or specify an integer > 0")
    ).toBeFalsy()
  })

  test("Spinner when loading ", async () => {
    cleanup()
    let r = render(
      <ConfigForm
        caches={[]}
        waiting={true}
        modelToReps={essenceFileToReps}
        essenceFiles={[essenceFile]}
        paramFiles={[paramFile]}
        submitHandler={mockHandler}
      />
    )
    // await waitForElement(() => r.getByTestId("spinner"))

    await wait(() => {})
    expect(r.queryByText("Solve")).toBeFalsy()
    expect(r.queryByRole("progressbar")).toBeTruthy()
  })


  test("choose cache", async () => {
    fireEvent.change(rendered.getByTestId("Caches-select"), {
      target: { value: findAllCache.name }
    })

    await wait(() => {})

    // expect(mockHandler.mock.calls.length).toEqual(1)
    expect(
      rendered.getByLabelText(/Model/, {
        selector: "input"
      })
    ).toHaveValue(findAllCache.essenceFile)
  })
})
