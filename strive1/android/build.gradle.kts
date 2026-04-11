buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
    }
}

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
    val projectPath = project.projectDir.absolutePath
    val buildPath = newBuildDir.asFile.absolutePath
    if (projectPath.length > 2 && buildPath.length > 2 && projectPath[1] == ':' && buildPath[1] == ':' && !projectPath.substring(0, 2).equals(buildPath.substring(0, 2), ignoreCase = true)) {
        val tempFile = java.io.File(java.io.File(System.getProperty("java.io.tmpdir"), "strive1_build"), project.name)
        project.layout.buildDirectory.set(tempFile)
    } else {
        val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
        project.layout.buildDirectory.value(newSubprojectBuildDir)
    }
}

subprojects {
    val project = this
    fun applyNamespaceFix() {
        if (project.extensions.findByName("android") != null) {
            val android = project.extensions.getByName("android")
            try {
                // Force compileSdk to 36 for all subprojects
                val setCompileSdk = android.javaClass.getMethod("setCompileSdk", Integer::class.java)
                setCompileSdk.invoke(android, 36)

                val getNamespace = android.javaClass.getMethod("getNamespace")
                val namespace = getNamespace.invoke(android)
                if (namespace == null) {
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    setNamespace.invoke(android, project.group.toString())
                }
            } catch (e: Exception) {
                // Method might not exist in older AGP versions
            }
        }
    }

    if (project.state.executed) {
        applyNamespaceFix()
    } else {
        project.afterEvaluate {
            applyNamespaceFix()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
// Force IDE cache invalidation sync
