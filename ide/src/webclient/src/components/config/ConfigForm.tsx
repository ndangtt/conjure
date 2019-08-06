import * as React from "react"
import TextWithLabel from "./TextWithLabel"
import SelectWithLabel from "./SelectWithLabel"
import StageHeader from "../common/StageHeader"
import { Check } from "../common/Check"
import { validationSchema } from "./Validation"
import { Cache, RepMap } from "../../../../extension/src/utils"

import {
  Form,
  Field,
  FieldArray,
  FieldProps,
  Formik,
  FormikProps
} from "formik"
import { MinionConfig, MinionStage } from "./MinionStage"
import { SRConfig, SRStage } from "./SRStage"
import { ConjureConfig, ConjureStage } from "./ConjureStage"
import { cloneDeep } from "lodash"
import { ConfigArrayElement } from "./ConfigArrayElement"

interface Props {
  modelToReps: RepMap
  essenceFiles: string[]
  paramFiles: string[]
  submitHandler: (values: Values) => void
}

interface State {
  diff: boolean
}

export interface CombinedConfig {
  conjureConfig: ConjureConfig
  srConfig: SRConfig
  minionConfig: MinionConfig
}

interface Values {
  caches: Cache[]
}

export class ConfigForm extends React.Component<Props, State> {
  state = {
    diff: false
  }

  render = () => {
    const initialCache = {
      name: "",
      essenceFile: this.props.essenceFiles[0],
      paramFile: this.props.paramFiles[0],
      config: {
        conjureConfig: { conjureTime: "", strategy: "", answers: [] },
        srConfig: {
          optimisation: "",
          symmetry: "",
          translation: "",
          srTime: "",
          cnfLimit: ""
        },
        minionConfig: {
          nodeLimit: "",
          solLimit: "",
          minionTime: "",
          preprocessing: "",
          consistency: "",
          minionSwitches: []
        }
      }
    }

    const initialCaches = [initialCache, cloneDeep(initialCache)]

    return (
      <Formik
        initialValues={{
          caches: initialCaches
        }}
        onSubmit={this.props.submitHandler}
        validationSchema={validationSchema}
        enableReinitialize={true}
        render={(renderProps: FormikProps<Values>) => {
          const values = renderProps.values

          const arrayIndexes = this.state.diff ? [0, 1] : [0]

          console.log(values.caches)

          const array = arrayIndexes.map(index => (
            <div className="col" key={index}>
              <Field
                name={`caches[${index}]`}
                component={ConfigArrayElement}
                modelToReps={this.props.modelToReps}
                essenceFiles={this.props.essenceFiles}
                paramFiles={this.props.paramFiles}
                index={index}
                values={{ cache: values.caches[index] }}
              />
            </div>
          ))

          return (
            <Form>
              <Check
                title={"Compare trees"}
                checked={this.state.diff}
                onChange={() => {
                  this.setState((prevState: State) => {
                    return { diff: !prevState.diff }
                  })
                }}
              />

              <div className="row">{array}</div>

              {/* <Field
                name={`caches[${index}]`}
                component={ConfigArrayElement}
                modelToReps={this.props.modelToReps}
                essenceFiles={this.props.essenceFiles}
                paramFiles={this.props.paramFiles}
                index={0}
                values={{ cache: values.caches[0] }}
              /> */}

              <button
                type="submit"
                className="btn btn-primary btn-lg btn-block"
                // onClick={() => console.log("Clicked submit button")}
              >
                Solve
              </button>
            </Form>
          )
        }}
      ></Formik>
    )
  }
}
