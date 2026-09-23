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

package mods

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

class ModsDatabaseOpenHelper private constructor(ctx: Context)
    : SQLiteOpenHelper(ctx.applicationContext, "ModsDatabase", null, 1) {

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE IF NOT EXISTS mod ("
            + "type INTEGER, filename TEXT, load_order INTEGER, enabled INTEGER)")
        db.execSQL("CREATE INDEX IF NOT EXISTS mod_type ON mod (type)")
        db.execSQL("CREATE INDEX IF NOT EXISTS mod_filename ON mod (filename)")
        db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS mod_type_name ON mod (type, filename)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
    }

    companion object {
        private var instance: ModsDatabaseOpenHelper? = null

        @Synchronized
        fun getInstance(ctx: Context): ModsDatabaseOpenHelper {
            if (instance == null)
                instance = ModsDatabaseOpenHelper(ctx.applicationContext)
            return instance!!
        }
    }
}

// Runs a block on an opened database, closing it afterwards
inline fun <T> ModsDatabaseOpenHelper.use(block: (SQLiteDatabase) -> T): T {
    val db = writableDatabase
    try {
        return block(db)
    } finally {
        db.close()
    }
}

// Access property for Context
val Context.database: ModsDatabaseOpenHelper
    get() = ModsDatabaseOpenHelper.getInstance(this)
