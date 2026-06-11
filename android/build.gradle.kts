allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

subprojects {
    val configureNamespace = Action<Project> {
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                val getNamespace = android.javaClass.getMethod("getNamespace")
                val namespace = getNamespace.invoke(android) as? String
                if (namespace == null || namespace.isEmpty()) {
                    val manifestFile = file("src/main/AndroidManifest.xml")
                    if (manifestFile.exists()) {
                        val manifestText = manifestFile.readText()
                        val matcher = java.util.regex.Pattern.compile("package=\"([^\"]+)\"").matcher(manifestText)
                        if (matcher.find()) {
                            val pkg = matcher.group(1)
                            val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                            setNamespace.invoke(android, pkg)
                        }
                    }
                }
            } catch (e: Exception) {
                // Method not found or reflection failed, ignore
            }
        }
    }
    if (state.executed) {
        configureNamespace.execute(this)
    } else {
        afterEvaluate {
            configureNamespace.execute(this)
            
            // Force compileSdk 34 to fix older plugins like flutter_bluetooth_serial
            val androidExt = extensions.findByName("android")
            if (androidExt != null) {
                try {
                    val setCompileSdk = androidExt.javaClass.getMethod("setCompileSdkVersion", Int::class.java)
                    setCompileSdk.invoke(androidExt, 34)
                } catch (e: Exception) {}
                try {
                    val setCompileSdk = androidExt.javaClass.getMethod("setCompileSdk", Int::class.java)
                    setCompileSdk.invoke(androidExt, 34)
                } catch (e: Exception) {}
            }
        }
    }
}
