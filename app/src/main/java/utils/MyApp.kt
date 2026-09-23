/*
    Copyright (C) 2019 Ilya Zhuravlev

    This file is part of OpenMW-Android.

    OpenMW-Android is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    OpenMW-Android is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with OpenMW-Android.  If not, see <https://www.gnu.org/licenses/>.
*/

package utils

import android.app.Application
import android.os.Environment
import com.libopenmw.openmw.BuildConfig
import constants.Constants
import java.io.File

class MyApp : Application() {

    var defaultScaling = 0f

    override fun onCreate() {
        app = this

        super.onCreate()

        // Set up global paths
        // Slug will be either omw or omw_nightly
        val slug = BuildConfig.APPLICATION_ID.split(".")[2]
        Constants.USER_FILE_STORAGE = Environment.getExternalStorageDirectory().toString() + "/$slug/"
        Constants.USER_CONFIG = "${Constants.USER_FILE_STORAGE}/config"
        Constants.USER_OPENMW_CFG =  "${Constants.USER_CONFIG}/openmw.cfg"
        Constants.DEFAULTS_BIN = File(filesDir, "config/defaults.bin").absolutePath
        Constants.OPENMW_CFG = File(filesDir, "config/openmw.cfg").absolutePath
        Constants.OPENMW_BASE_CFG = File(filesDir, "config/openmw.base.cfg").absolutePath
        Constants.OPENMW_FALLBACK_CFG = File(filesDir, "config/openmw.fallback.cfg").absolutePath
        Constants.RESOURCES = File(filesDir, "resources").absolutePath
        Constants.GLOBAL_CONFIG = File(filesDir, "config").absolutePath
        Constants.VERSION_STAMP = File(filesDir, "stamp").absolutePath
    }

    companion object {
        lateinit var app: MyApp
    }
}
