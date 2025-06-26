import 'dart:convert';

import 'package:firebase_dart/src/database/impl/operations/tree.dart';
import 'package:firebase_dart/src/database/impl/persistence/prune_forest.dart';
import 'package:firebase_dart/src/database/impl/persistence/tracked_query.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/extension.dart';

import '../data_observer.dart';
import '../tree.dart';
import '../treestructureddata.dart';
import '../utils.dart';
import 'engine.dart';

class PersistenceStorageTransaction {
  final Map<int, TrackedQuery?> _trackedQueries = {};
  final Map<int, TreeOperation?> _userOperations = {};
  IncompleteData? _serverCache;

  PersistenceStorageTransaction();

  bool get isEmpty =>
      _trackedQueries.isEmpty &&
      _userOperations.isEmpty &&
      _serverCache == null;

  void deleteTrackedQuery(int trackedQueryId) {
    _trackedQueries[trackedQueryId] = null;
  }

  void saveTrackedQuery(TrackedQuery trackedQuery) {
    _trackedQueries[trackedQuery.id] = trackedQuery;
  }

  void deleteUserOperation(int writeId) {
    _userOperations[writeId] = null;
  }

  void saveUserOperation(TreeOperation operation, int writeId) {
    _userOperations[writeId] = operation;
  }

  void saveServerCache(IncompleteData value) {
    _serverCache = value;
  }

  void addTransaction(PersistenceStorageTransaction transaction) {
    _trackedQueries.addAll(transaction._trackedQueries);
    _userOperations.addAll(transaction._userOperations);
    _serverCache = transaction._serverCache ?? _serverCache;
  }
}

abstract class PersistenceStorageDatabase {
  IncompleteData loadServerCache();

  List<TrackedQuery> loadTrackedQueries();

  Map<int, TreeOperation> loadUserOperations();

  Future<void> applyTransaction(PersistenceStorageTransaction transaction);

  Future<void> close();

  bool get isOpen;
}

class SharedPrefsPersistenceStorageDatabase extends PersistenceStorageDatabase {
  final String _storageName;
  late final String _serverCachePrefix;
  late final String _trackedQueryPrefix;
  late final String _userWritesPrefix;
  late final String _serverCacheKeysKey;

  SharedPreferences? _prefs;
  late IncompleteData? _lastWrittenServerCache;

  SharedPrefsPersistenceStorageDatabase(this._storageName) {
    _serverCachePrefix = '${_storageName}_cache_';
    _trackedQueryPrefix = '${_storageName}_query_';
    _userWritesPrefix = '${_storageName}_write_';
    _serverCacheKeysKey = '${_storageName}_cache_keys';
  }

  Future<void> _ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  IncompleteData loadServerCache() {
    assert(isOpen);
    _lastWrittenServerCache ??= _loadServerCache();
    return _lastWrittenServerCache!;
  }

  IncompleteData _loadServerCache() {
    final cacheKeysJson = _prefs!.getString(_serverCacheKeysKey);
    if (cacheKeysJson == null) {
      return IncompleteData.empty();
    }

    final cacheKeys = List<String>.from(json.decode(cacheKeysJson));
    final Map<Path<Name>, TreeStructuredData> leafs = {};

    for (final key in cacheKeys) {
      final dataJson = _prefs!.getString('$_serverCachePrefix$key');
      if (dataJson != null) {
        final path = Name.parsePath(key);
        final data = TreeStructuredData.fromExportJson(json.decode(dataJson));
        leafs[path] = data;
      }
    }

    return IncompleteData.fromLeafs(leafs);
  }

  @override
  List<TrackedQuery> loadTrackedQueries() {
    assert(isOpen);
    if (_prefs == null) return [];

    final keys = _prefs!
        .getKeys()
        .where((key) => key.startsWith(_trackedQueryPrefix))
        .toList();

    final queries = <TrackedQuery>[];
    for (final key in keys) {
      final jsonString = _prefs!.getString(key);
      if (jsonString != null) {
        try {
          final queryData = json.decode(jsonString);
          queries.add(TrackedQuery.fromJson(queryData));
        } catch (e) {
          // Skip malformed queries
          continue;
        }
      }
    }

    queries.sort((a, b) => Comparable.compare(a.id, b.id));
    return queries;
  }

  @override
  Map<int, TreeOperation> loadUserOperations() {
    assert(isOpen);
    if (_prefs == null) return {};

    final keys = _prefs!
        .getKeys()
        .where((key) => key.startsWith(_userWritesPrefix))
        .toList();

    final operations = <int, TreeOperation>{};
    for (final key in keys) {
      final jsonString = _prefs!.getString(key);
      if (jsonString != null) {
        try {
          final writeId = int.parse(key.substring(_userWritesPrefix.length));
          final operationData = json.decode(jsonString);
          operations[writeId] = TreeOperationX.fromJson(operationData);
        } catch (e) {
          // Skip malformed operations
          continue;
        }
      }
    }

    return operations;
  }

  @override
  Future<void> applyTransaction(
      PersistenceStorageTransaction transaction) async {
    await _ensureInitialized();
    assert(isOpen);

    // Handle tracked queries
    for (final entry in transaction._trackedQueries.entries) {
      final trackedQueryId = entry.key;
      final trackedQuery = entry.value;
      final key = '$_trackedQueryPrefix$trackedQueryId';

      if (trackedQuery == null) {
        await _prefs!.remove(key);
      } else {
        final jsonString = json.encode(trackedQuery.toJson());
        await _prefs!.setString(key, jsonString);
      }
    }

    // Handle user operations
    for (final entry in transaction._userOperations.entries) {
      final writeId = entry.key;
      final operation = entry.value;
      final key = '$_userWritesPrefix$writeId';

      if (operation == null) {
        await _prefs!.remove(key);
      } else {
        final jsonString = json.encode(operation.toJson());
        await _prefs!.setString(key, jsonString);
      }
    }

    // Handle server cache
    final serverCache = transaction._serverCache;
    if (serverCache != null) {
      await _writeServerCache(serverCache);
      _lastWrittenServerCache = serverCache;
    }
  }

  Future<void> _writeServerCache(IncompleteData serverCache) async {
    // Get current cache keys
    final currentCacheKeysJson = _prefs!.getString(_serverCacheKeysKey);
    final currentCacheKeys = currentCacheKeysJson != null
        ? Set<String>.from(json.decode(currentCacheKeysJson))
        : <String>{};

    final newCacheKeys = <String>{};

    void write(Path<Name> path, TreeNode<Name, TreeStructuredData?> value,
        TreeNode<Name, TreeStructuredData?> lastWritten) {
      if (value.value != null && lastWritten.value == value.value) return;

      final pathString = path.join('/');

      if (value.value != null || lastWritten.value != null) {
        // Remove child cache entries for this path
        final childKeysToRemove = currentCacheKeys
            .where((key) => key.startsWith('$pathString/'))
            .toList();

        for (final childKey in childKeysToRemove) {
          _prefs!.remove('$_serverCachePrefix$childKey');
          currentCacheKeys.remove(childKey);
        }
      }

      if (value.value != null) {
        final data = value.value!;
        // Ensure default query filter
        assert(data.filter == const QueryFilter());

        final jsonString = json.encode(data.toJson(true));
        _prefs!.setString('$_serverCachePrefix$pathString/', jsonString);
        newCacheKeys.add('$pathString/');
      } else {
        // Handle children recursively
        final allChildren = [
          ...lastWritten.children.keys,
          ...value.children.keys
        ];

        for (final childKey in allChildren) {
          write(
            path.child(childKey),
            value.children[childKey] ?? const LeafTreeNode(null),
            lastWritten.children[childKey] ?? const LeafTreeNode(null),
          );
        }
      }
    }

    write(Path(), serverCache.writeTree, _lastWrittenServerCache!.writeTree);

    // Update cache keys list
    currentCacheKeys.addAll(newCacheKeys);
    final updatedCacheKeysJson = json.encode(currentCacheKeys.toList());
    await _prefs!.setString(_serverCacheKeysKey, updatedCacheKeysJson);
  }

  @override
  Future<void> close() async {
    // SharedPreferences doesn't need explicit closing
    _prefs = null;
  }

  @override
  bool get isOpen => true; // SharedPreferences is always available

  /// Ensures SharedPreferences is initialized - called automatically when needed
  Future<void> ensureInitialized() async {
    await _ensureInitialized();
    _lastWrittenServerCache ??= _loadServerCache();
  }
}

class DebouncedPersistenceStorageDatabase
    implements PersistenceStorageDatabase {
  final PersistenceStorageDatabase delegateTo;

  PersistenceStorageTransaction _transaction = PersistenceStorageTransaction();

  DelayedCancellableFuture<void>? _writeToDatabaseFuture;

  DebouncedPersistenceStorageDatabase(this.delegateTo);

  @override
  Future<void> applyTransaction(
      PersistenceStorageTransaction transaction) async {
    assert(isOpen);
    _transaction.addTransaction(transaction);
    _scheduleWriteToDatabase();
  }

  @override
  Future<void> close() async {
    assert(isOpen);
    _writeToDatabaseFuture?.cancel();
    await _writeToDatabase();
    await delegateTo.close();
  }

  @override
  IncompleteData loadServerCache() {
    assert(isOpen);
    return _transaction._serverCache ?? delegateTo.loadServerCache();
  }

  @override
  List<TrackedQuery> loadTrackedQueries() {
    assert(isOpen);
    return [
      ...delegateTo
          .loadTrackedQueries()
          .where((v) => !_transaction._trackedQueries.containsKey(v.id)),
      ..._transaction._trackedQueries.values.whereType()
    ];
  }

  @override
  Map<int, TreeOperation> loadUserOperations() {
    assert(isOpen);
    return ({
      ...delegateTo.loadUserOperations(),
      ..._transaction._userOperations,
    }..removeWhere((key, value) => value == null))
        .cast();
  }

  void _scheduleWriteToDatabase() {
    _writeToDatabaseFuture ??=
        DelayedCancellableFuture(const Duration(milliseconds: 500), () {
      if (_writeToDatabaseFuture == null) return;
      synchronized(_writeToDatabase);
    });
  }

  Future<void> _writeToDatabase() async {
    assert(isOpen);
    _writeToDatabaseFuture = null;

    if (_transaction.isEmpty) return;

    await delegateTo.applyTransaction(_transaction);
    _transaction = PersistenceStorageTransaction();
  }

  @override
  bool get isOpen => delegateTo.isOpen;
}

class SharedPrefsPersistenceStorageEngine extends PersistenceStorageEngine {
  final PersistenceStorageDatabase database;

  PersistenceStorageTransaction? _transaction;

  SharedPrefsPersistenceStorageEngine(String persistenceStorageName)
      : database = DebouncedPersistenceStorageDatabase(
          SharedPrefsPersistenceStorageDatabase(persistenceStorageName),
        );

  @override
  void beginTransaction() {
    assert(_transaction == null);
    _transaction = PersistenceStorageTransaction();
  }

  @override
  void deleteTrackedQuery(int trackedQueryId) {
    assert(_transaction != null);
    _transaction!.deleteTrackedQuery(trackedQueryId);
  }

  @override
  void endTransaction() {
    assert(_transaction != null);
    database.applyTransaction(_transaction!);
    _transaction = null;
  }

  @override
  List<TrackedQuery> loadTrackedQueries() {
    return database.loadTrackedQueries();
  }

  @override
  Map<int, TreeOperation> loadUserOperations() {
    return database.loadUserOperations();
  }

  @override
  void overwriteServerCache(TreeOperation operation) {
    _saveServerCache(database.loadServerCache().applyOperation(operation));
  }

  void _saveServerCache(IncompleteData serverCache) {
    assert(_transaction != null);
    _transaction!.saveServerCache(serverCache);
  }

  @override
  void pruneCache(PruneForest pruneForest) {
    assert(_transaction != null);
    if (!pruneForest.prunesAnything()) {
      return;
    }

    var serverCache = database.loadServerCache();

    serverCache.forEachCompleteNode((dataPath, value) {
      final dataNode = value;

      if (pruneForest.shouldPruneUnkeptDescendants(dataPath)) {
        var newCache = pruneForest
            .child(dataPath)
            .foldKeptNodes<IncompleteData>(IncompleteData.empty(),
                (keepPath, value, accum) {
          var value = dataNode.getChild(keepPath);
          if (!value.isNil) {
            var op = TreeOperation.overwrite(
                Path.from([...dataPath, ...keepPath]),
                dataNode.getChild(keepPath));
            accum = accum.applyOperation(op);
          }
          return accum;
        });
        serverCache = serverCache
            .removeWrite(dataPath)
            .applyOperation(newCache.toOperation());
      }
    });

    _saveServerCache(serverCache);
  }

  @override
  void removeUserOperation(int writeId) {
    assert(_transaction != null);
    _transaction!.deleteUserOperation(writeId);
  }

  @override
  void resetPreviouslyActiveTrackedQueries(DateTime lastUse) {
    for (var query in loadTrackedQueries()) {
      if (query.active) {
        query = query.setActiveState(false).updateLastUse(lastUse);
        saveTrackedQuery(query);
      }
    }
  }

  @override
  void saveTrackedQuery(TrackedQuery trackedQuery) {
    assert(_transaction != null);
    _transaction!.saveTrackedQuery(trackedQuery);
  }

  @override
  void saveUserOperation(TreeOperation operation, int writeId) {
    assert(_transaction != null);
    _transaction!.saveUserOperation(operation, writeId);
  }

  @override
  IncompleteData serverCache(Path<Name> path) {
    return database.loadServerCache().child(path);
  }

  @override
  int serverCacheEstimatedSizeInBytes() {
    return _transaction?._serverCache?.estimatedStorageSize ??
        database.loadServerCache().estimatedStorageSize;
  }

  @override
  void setTransactionSuccessful() {}

  @override
  Future<void> close() async {
    await database.close();
  }
}

extension IncompleteDataX on IncompleteData {
  int get estimatedStorageSize {
    var bytes = 0;
    forEachCompleteNode((k, v) {
      bytes +=
          k.join('/').length + json.encode(v.toJson(true)).toString().length;
    });
    return bytes;
  }
}

extension TreeOperationX on TreeOperation {
  static TreeOperation fromJson(Map<String, dynamic> json) {
    if (json.containsKey('s')) {
      return TreeOperation.overwrite(
          Name.parsePath(json['p']), TreeStructuredData.fromJson(json['s']));
    }
    var v = json['m'] as Map;
    return TreeOperation.merge(Name.parsePath(json['p']), {
      for (var k in v.keys) Name.parsePath(k): TreeStructuredData.fromJson(v[k])
    });
  }

  Map<String, dynamic> toJson() {
    var o = nodeOperation;
    return {
      'p': path.join('/'),
      if (o is Overwrite) 's': o.value.toJson(true),
      if (o is Merge)
        'm': {
          for (var c in o.overwrites)
            c.path.join('/'): (c.nodeOperation as Overwrite).value.toJson(true)
        }
    };
  }
}
