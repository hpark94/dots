local home = os.getenv("HOME")

local jdtls_path = home .. "/.local/share/jdtls"
local jdtls_launcher = vim.fn.glob(
    jdtls_path .. "/plugins/org.eclipse.equinox.launcher_*.jar",
    true
)
local jdtls_config = jdtls_path .. "/config_linux"
local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")
local workspace_dir = vim.fn.stdpath("data")
    .. "/jdtls/workspace/"
    .. project_name

local vscode_path = home .. "/.local/share/vscode-plugins"
local vscode_debugger = vscode_path
    .. "/debug/com.microsoft.java.debug.plugin-*.jar"
local vscode_test = vscode_path .. "/test/*.jar"

local bundles = {
    vim.fn.glob(vscode_debugger, true),
}

local java_test_bundles = vim.split(vim.fn.glob(vscode_test, true), "\n")

local excluded = {
    "com.microsoft.java.test.runner-jar-with-dependencies.jar",
    "jacocoagent.jar",
}

for _, java_test_jar in ipairs(java_test_bundles) do
    local fname = vim.fn.fnamemodify(java_test_jar, ":t")
    if not vim.tbl_contains(excluded, fname) then
        table.insert(bundles, java_test_jar)
    end
end

local config = {
    name = "jdtls",
    cmd = {
        "java",
        "-Declipse.application=org.eclipse.jdt.ls.core.id1",
        "-Dosgi.bundles.defaultStartLevel=4",
        "-Declipse.product=org.eclipse.jdt.ls.core.product",
        "-Dlog.level=ALL",
        "-Xms1G",
        "-Xmx2G",
        "--add-modules=ALL-SYSTEM",
        "--add-opens",
        "java.base/java.util=ALL-UNNAMED",
        "--add-opens",
        "java.base/java.lang=ALL-UNNAMED",
        "-javaagent:" .. home .. "/.local/share/java/lombok.jar",
        "-jar",
        jdtls_launcher,
        "-configuration",
        jdtls_config,
        "-data",
        workspace_dir,
    },
    root_dir = vim.fs.root(0, {
        ".git",
        "mvnw",
        "gradlew",
        "pom.xml",
    }),
    settings = {
        java = {
            format = {
                enabled = true,
                settings = {
                    url = vim.fn.expand("~/MyDefault.xml"),
                    profile = "MyDefault",
                },
            },
            eclipse = {
                downloadSources = true,
            },
            maven = {
                downloadSources = true,
            },
            implementationsCodeLens = {
                enabled = true,
            },
            referencesCodeLens = {
                enabled = true,
            },
        },
    },
    init_options = {
        bundles = bundles,
    },
}

require("jdtls").start_or_attach(config)
