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
    // Some transitive plugins (e.g. passkeys_*, pulled in by supabase_flutter)
    // pin their compileSdk to 35, but package_info_plus requires consumers to
    // compile against API 36+. Force every Android subproject to at least 36.
    // Registered before evaluationDependsOn below so it isn't added after the
    // subproject has already been evaluated. Reflection is used because library
    // and application modules expose different extension types.
    afterEvaluate {
        val androidExt = extensions.findByName("android") ?: return@afterEvaluate
        // Look the setter up by name (not signature): `compileSdk: Int?` exposes
        // a setter taking a boxed Integer, so a primitive-int lookup would miss.
        val getter = androidExt.javaClass.methods
            .firstOrNull { it.name == "getCompileSdk" && it.parameterCount == 0 }
        val setter = androidExt.javaClass.methods
            .firstOrNull { it.name == "setCompileSdk" && it.parameterCount == 1 }
        if (setter != null) {
            val current = getter?.invoke(androidExt) as? Int
            if (current == null || current < 36) {
                setter.invoke(androidExt, 36)
            }
        }
    }

    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
