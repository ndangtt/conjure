import * as path from "path"
import * as vscode from "vscode"
import * as express from "express"
import fs = require("fs")
import { sortBy, isEqual, head } from "lodash"

import {
  Server,
  Path,
  GET,
  POST,
  PathParam,
  QueryParam,
  Errors
} from "typescript-rest"

import * as init from "./init"
import * as cors from "cors"
const fetch = require("node-fetch")

import ConfigHelper, { RepMap, hasher } from "../configHelper"
import { Cache } from "../configHelper"
import { execSync } from "child_process"
import { Core } from "../webclient/components/vis/TreeContainer"

const collator = new Intl.Collator(undefined, { numeric: true })

interface FilesResponse {
  models: string[]
  params: string[]
  representations: RepMap
}

export interface InitResponse {
  trees: { core: Core; info: string; path: string; hash: string }[]
  nimServerPort: number
  vscodeServerPort: number
}

let nimServerPort: number
let thisServerPort: number
let context: vscode.ExtensionContext

@Path("/")
class HTMlService {
  @Path("/")
  @GET
  getPage(): string {
    let html =
      fs
        .readFileSync(
          path.join(context.extensionPath, "src/webclient/index.html")
        )
        .toString() +
      `
      <div id="port" vscodeServerPort="${thisServerPort}"></div>
    <script>${fs
      .readFileSync(path.join(context.extensionPath, "dist/configBundle.js"))
      .toString()}</script>
  </body>
</html>
      `

    console.log(html)
    return html
  }
}

@Path("/config")
class ConfigService {
  toRel(uri: vscode.Uri): string {
    return vscode.workspace.asRelativePath(uri.path)
  }

  @Path("/invalidateCaches")
  @GET
  async invalidateCaches() {
    await ConfigHelper.invalidateCaches()
  }

  @Path("/caches")
  @GET
  async getCaches(): Promise<Cache[]> {
    let cachedFiles = await vscode.workspace.findFiles(
      `**/${ConfigHelper.cacheFileName}`
    )

    return sortBy(
      cachedFiles.map(uri => {
        return {
          name: path.basename(path.dirname(uri.path)),
          config: JSON.parse(fs.readFileSync(uri.path).toString()).config
        }
      }),
      ["name"]
    ).reverse()
  }

  @Path("/files")
  @GET
  async getFiles(): Promise<FilesResponse> {
    let models = await vscode.workspace.findFiles("**/*.essence")
    let params = await vscode.workspace.findFiles("**/*.param")

    let reps = models.map(model => {
      return {
        name: this.toRel(model),
        representations: JSON.parse(
          execSync(
            `conjure ide ${model.path} --dump-representations`
          ).toString()
        )
      }
    })

    let map: any = {}

    reps.forEach(r => {
      map[r.name] = r.representations
    })

    return {
      models: models.map(uri => this.toRel(uri)).sort(collator.compare),
      params: params.map(uri => this.toRel(uri)).sort(collator.compare),
      representations: map
    }
  }

  @Path("/solve")
  @POST
  async startSearch(list: Cache[]): Promise<InitResponse> {
    console.log("SOLLLLLLLLLLLLLLLLLLLLVE REQUEST", list)

    let configsAreTheSame = isEqual(list[0], list[1])
    // vscode.window.showErrorMessage("Configs are the same! aborting..")
    // return

    let jobs = configsAreTheSame ? [list[0]] : list

    const { needToGenerate, loadFromCache } = await ConfigHelper.separateJobs(
      jobs
    )

    return vscode.window
      .withProgress(
        {
          cancellable: true,
          location: vscode.ProgressLocation.Notification,
          title: "Solving "
        },
        (progress, token) => {
          return ConfigHelper.makePromise(needToGenerate, progress, token)
        }
      )
      .then(() => {
        return vscode.window.withProgress(
          {
            cancellable: false,
            location: vscode.ProgressLocation.Notification,
            title: "Processing Tree"
          },
          async () => {
            const inits = await Promise.all(
              list.map(async tree => {
                const fullPath = path.join(
                  ConfigHelper.cacheFolderPath,
                  tree.name
                )

                const response = await fetch(
                  `http://localhost:${nimServerPort}/init/${fullPath}`
                )

                const json = (await response.json()) as {
                  core: Core
                  info: string
                }

                // json["hash"] = hasher(tree.config)

                // json["path"] = fullPath
                // console.log(json)

                return {
                  hash: hasher(tree.config),
                  path: fullPath,
                  ...json
                }
              })
            )

            const response = {
              trees: inits,
              nimServerPort: nimServerPort,
              vscodeServerPort: thisServerPort
            }

            // console.log(inits)
            return response
          }
        )
      })
  }
}

@Path("/hello")
class HelloService {
  @Path(":name")
  @GET
  sayHello(@PathParam("name") name: string): string {
    return "Hello " + name
  }
}

@Path("/init")
class Init {
  @GET
  init(@QueryParam("path") path: string) {
    try {
      init.findFiles(path)
    } catch (e) {
      vscode.window.showErrorMessage(e.message)
      return new Errors.BadRequestError("Invalid init path: " + e.message)
    }
    return "We got this path " + path
  }
}

export function startServer(
  nsPort: number,
  vscodeServerPort: number,
  ctx: vscode.ExtensionContext
) {
  nimServerPort = nsPort
  thisServerPort = vscodeServerPort
  context = ctx

  let app: express.Application = express()
  app.use(cors())
  Server.buildServices(app)

  app.listen(vscodeServerPort, function() {
    console.log(`Rest Server listening on port ${vscodeServerPort}!`)
  })
}
