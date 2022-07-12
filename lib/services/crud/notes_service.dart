// work with sqlite database
// create, read, update, delete, find users and notes

// import dependencies
import 'dart:html';

import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:path/path.dart' as path show join;
import 'package:path_provider/path_provider.dart' as path_provider;

// ## we need to construct our database path
// grab and hold up current database path
// every application developed with flutter have their own document directory
// join path of the document directory using the path dependency with the name specified in the database

// ## we need database users
// create databaseuser class inside notes_service.dart
class DatabaseAlreadyOpenException implements Exception {}

class UnableToGetDocumentsDirectory implements Exception {}

class DatabaseIsNotOpen implements Exception {}

class CouldNotDeleteUser implements Exception {}

class UserAlreadyExist implements Exception {}

class CouldNotFindUser implements Exception {}

class CouldNotDeleteNote implements Exception {}

class CouldNotFindNote implements Exception{}

class CouldNotUpdateNote implements Exception {}


class NotesService {
  sqflite.Database? _db; // from sqflite dependency

  sqflite.Database _getDatabaseOrThrow() {
    final db = _db;
    if (db == null) {
      throw DatabaseIsNotOpen();
    } else {
      return db;
    }
  }

  Future<void> close() async {
    final db = _db;
    if (db == null) {
      throw DatabaseIsNotOpen();
    } else {
      await db.close();
      _db = null;
    }
  }

  //we need an async function that open database
  Future<void> open() async {
    //open and hold up the database
    if (_db != null) {
      throw DatabaseAlreadyOpenException();
    }
    try {
      //why try catch? -> in getApplicationDocumentsDirectory(), Throws a `MissingPlatformDirectoryException` if the system is unable to provide the directory.
      final docsPath = await path_provider
          .getApplicationDocumentsDirectory(); //get document directory
      final dbPath = path.join(docsPath.path,
          dbName); //join document directory and database file name
      final db = await sqflite.openDatabase(
          dbPath); //open database & if it doesnt exist then create the new one
      _db = db;

      //to create user table when the database doesn't exist
      await db.execute(createUserTable);

      //to create note table when the database doesn't exist
      await db.execute(createNoteTable);

      //question: how flutter application create database table and read it?

    } on path_provider.MissingPlatformDirectoryException {
      throw UnableToGetDocumentsDirectory();
    }
  }

  Future<void> deleteUser({
    required String email,
  }) async {
    final db = _getDatabaseOrThrow();
    final deletedCount = await db.delete(
      userTable,
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
    );
    if (deletedCount != 1) throw CouldNotDeleteUser();
  }

  Future<DatabaseUser> createUser({
    required String email,
  }) async {
    final db = _getDatabaseOrThrow();
    final results = await db.query(
      //look for a given email on the email column in the user table
      userTable,
      limit: 1,
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
    );
    if (results.isNotEmpty) throw UserAlreadyExist();

    final newUserId = await db.insert(userTable, {
      //for id, it will autumatically be increased by 1
      emailColumn: email.toLowerCase(),
    });

    return DatabaseUser(
      id: newUserId,
      email: email,
    );
  }

  Future<DatabaseUser> getUser({
    required String email,
  }) async {
    final db = _getDatabaseOrThrow();
    final results = await db.query(
      //look for a given email on the email column in the user table
      userTable,
      limit: 1,
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
    );
    if (results.isEmpty) throw CouldNotFindUser();
    return DatabaseUser.fromRow(results.first);
  }

  Future<DatabaseNote> createNote({
    required DatabaseUser owner,
  }) async {
    // the ownder could be simply created from anywhere,
    // So we want to make sure if that ownder is really a user in database
    // for example, you can hack the note by creating databaseuser manually when you know a email is used in database.
    // make sure ownder exists in the database with the correct id
    final db = _getDatabaseOrThrow();
    final dbUser = await getUser(email: owner.email);
    if (dbUser != owner) throw CouldNotFindUser();

    // create note
    const text = '';
    final newNoteId = await db.insert(noteTable, {
      userIdColumn: owner.id,
      textColumn: text,
      isSyncedWithCloudColumn: 1,
    });

    final newNote = DatabaseNote(
        id: newNoteId, userId: owner.id, text: text, isSyncedWithCloud: true);

    return newNote;
  }

  Future<void> deleteNote({required int id}) async {
    final db = _getDatabaseOrThrow();

    // delete note
    final deletedCount = await db.delete(
      noteTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    if(deletedCount == 0) throw CouldNotDeleteNote();

  }

  Future<int> deleteAllNotes() async {
    final db = _getDatabaseOrThrow();
    final deletedCount = await db.delete(noteTable);
    return deletedCount;
  }

  Future<DatabaseNote> getNote({required int id}) async {
    final db = _getDatabaseOrThrow();
    final notes = await db.query(
      //look for a given email on the email column in the note table
      userTable,
      limit: 1,
      where: 'id = ?',
      whereArgs: [id],
    );
    if(notes.isEmpty) throw CouldNotFindNote();
    return DatabaseNote.fromRow(notes.first);
  }

  Future<Iterable<DatabaseNote>> getAllNotes() async {
    final db = _getDatabaseOrThrow();
    final notes = await db.query(noteTable);
    return notes.map((noteRow) => DatabaseNote.fromRow(noteRow));
  }

  //pass a note that you want to update and an update context which is a text
  Future<DatabaseNote> updateNote({
    required DatabaseNote note,
    required String text,
  }) async {
    final db = _getDatabaseOrThrow();
    await getNote(id: note.id); //check if the passed note exist in the noteTable of the database
    final updatedCount = await db.update(
      noteTable,
      {
        textColumn: text,
        isSyncedWithCloudColumn: 0,
      },
    );
    if (updatedCount == 0) throw CouldNotUpdateNote();
    return await getNote(id: note.id);
  }

}



@immutable
class DatabaseUser {
  final int id;
  final String email;

  const DatabaseUser({
    required this.id,
    required this.email,
  });

  DatabaseUser.fromRow(Map<String, Object?> map)
      : id = map[idColumn] as int,
        email = map[emailColumn] as String;

  @override
  String toString() => 'Person, ID = $id, email = $email';

  @override
  bool operator ==(covariant DatabaseUser other) => id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// we also need a class for our notes
// create DatabaseNote in notes_service.dart

class DatabaseNote {
  final int id;
  final int userId;
  final String text;
  final bool isSyncedWithCloud;

  DatabaseNote({
    required this.id,
    required this.userId,
    required this.text,
    required this.isSyncedWithCloud,
  });

  DatabaseNote.fromRow(Map<String, Object?> map)
      : id = map[idColumn] as int,
        userId = map[userIdColumn] as int,
        text = map[textColumn] as String,
        isSyncedWithCloud = (map[isSyncedWithCloudColumn] as int) == 1
            ? true
            : false; // is_synched_with_cloud is Integer in sqlite database. so read it as integer and interpret it as bool

  @override
  String toString() =>
      'Note, ID = $id, userId = $userId, isSyncedWithCloud = $isSyncedWithCloud, text = $text';

  @override
  bool operator ==(covariant DatabaseNote other) => id == other.id;

  @override
  int get hashCode => id.hashCode;
}

const dbName = 'notes.db';
const noteTable = 'note';
const userTable = 'user';
const idColumn = 'id';
const emailColumn = 'email';
const userIdColumn = 'user_id';
const textColumn = 'text';
const isSyncedWithCloudColumn = 'is_synced_with_cloud';
const createUserTable = '''
  CREATE TABLE IF NOT EXISTS "user" (
    "id"	INTEGER NOT NULL,
    "email"	INTEGER NOT NULL UNIQUE,
    PRIMARY KEY("id" AUTOINCREMENT)
  );
''';
const createNoteTable = '''
CREATE TABLE IF NOT EXIST "note" (
  "id"	INTEGER NOT NULL,
  "user_id"	INTEGER NOT NULL,
  "text"	TEXT,
  "is_Synced_with_cloud"	INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY("user_id") REFERENCES "user"("id"),
  PRIMARY KEY("id" AUTOINCREMENT)
);
''';