import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:item_rdc/pdf_viewer.dart';
import 'package:item_rdc/video_player_page.dart';
import 'package:item_rdc/util/drive_util.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Library"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(context: context, delegate: CategorySearch());
            },
          ),
        ],
      ),
      body: const LibraryList(),
    );
  }
}

class LibraryList extends StatelessWidget {
  const LibraryList({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('categories').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("No content found"));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            String title = docs[index]['title'];
            return Card(
              child: ListTile(
                title: Text(title),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UniversityPage(
                        categoryId: docs[index].id,
                        categoryTitle: title,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class CategorySearch extends SearchDelegate {
  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('categories').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var filtered = snapshot.data!.docs.where((doc) => 
          doc['title'].toString().toLowerCase().contains(query.toLowerCase())).toList();
        if (filtered.isEmpty) return const Center(child: Text("No content found"));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            String title = filtered[index]['title'];
            return ListTile(
              title: Text(title),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => 
                UniversityPage(categoryId: filtered[index].id, categoryTitle: title))),
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);
}

class UniversityPage extends StatelessWidget {
  final String categoryId, categoryTitle;
  const UniversityPage({super.key, required this.categoryId, required this.categoryTitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(categoryTitle),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () => 
            showSearch(context: context, delegate: UniversitySearch(categoryId: categoryId))),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('categories').doc(categoryId).collection('universities').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              String uniName = docs[index]['name'];
              final logoUrl = docs[index]['logoUrl'];
              return ListTile(
                leading: logoUrl != null && logoUrl.toString().isNotEmpty
                    ? CircleAvatar(
                        backgroundColor: Colors.grey.shade200,
                        child: ClipOval(
                          child: Image.network(
                            logoUrl,
                            width: 40, height: 40, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.school),
                          ),
                        ),
                      )
                    : const CircleAvatar(child: Icon(Icons.school)),
                title: Text(uniName),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => 
                  DocumentPage(universityId: docs[index].id, uniName: uniName, categoryId: categoryId))),
              );
            },
          );
        },
      ),
    );
  }
}

class UniversitySearch extends SearchDelegate {
  final String categoryId;
  UniversitySearch({required this.categoryId});

  @override
  List<Widget>? buildActions(BuildContext context) => [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('categories').doc(categoryId).collection('universities').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var filtered = snapshot.data!.docs.where((doc) => doc['name'].toString().toLowerCase().contains(query.toLowerCase())).toList();
        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) => ListTile(
            title: Text(filtered[index]['name']),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => 
              DocumentPage(universityId: filtered[index].id, uniName: filtered[index]['name'], categoryId: categoryId))),
          ),
        );
      },
    );
  }
  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);
}

class DocumentPage extends StatefulWidget {
  final String universityId, uniName, categoryId;
  const DocumentPage({super.key, required this.universityId, required this.uniName, required this.categoryId});

  @override
  State<DocumentPage> createState() => _DocumentPageState();
}

class _DocumentPageState extends State<DocumentPage> {
  String filterType = "All";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.uniName),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () => 
            showSearch(context: context, delegate: DocumentSearch(categoryId: widget.categoryId, universityId: widget.universityId, filterType: filterType))),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ["All", "TFC", "Mémoire", "Internship"].map((type) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ChoiceChip(
                      label: Text(type),
                      selected: filterType == type,
                      onSelected: (selected) { if (selected) setState(() => filterType = type); },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('categories').doc(widget.categoryId)
                  .collection('universities').doc(widget.universityId).collection('documents').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var docs = snapshot.data!.docs.where((doc) => 
                  filterType == "All" ? true : (doc['type'] ?? "") == filterType).toList();

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    String url = doc['url'] ?? "";
                    String title = doc['title'] ?? "";
                    String type = doc['type'] ?? "";

                    return ListTile(
                      leading: Icon(DriveUtil.isVideo(url, type) ? Icons.play_circle_fill : Icons.description, 
                        color: DriveUtil.isVideo(url, type) ? Colors.blue : Colors.red),
                      title: Text(title),
                      subtitle: Text(doc['type'] ?? ""),
                      onTap: () {
                        if (DriveUtil.isVideo(url, type)) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerPage(url: url, title: title)));
                        } else {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => PdfViewer(url: url, title: title)));
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DocumentSearch extends SearchDelegate {
  final String categoryId, universityId, filterType;
  DocumentSearch({required this.categoryId, required this.universityId, required this.filterType});

  @override
  List<Widget>? buildActions(BuildContext context) => [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('categories').doc(categoryId).collection('universities').doc(universityId).collection('documents').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var filtered = snapshot.data!.docs.where((doc) {
          bool matchesSearch = doc['title'].toString().toLowerCase().contains(query.toLowerCase());
          bool matchesType = filterType == "All" ? true : (doc['type'] ?? "") == filterType;
          return matchesSearch && matchesType;
        }).toList();

        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            String url = filtered[index]['url'] ?? "";
            String title = filtered[index]['title'] ?? "";
            String type = filtered[index]['type'] ?? "";
            return ListTile(
              title: Text(title),
              onTap: () {
                if (DriveUtil.isVideo(url, type)) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerPage(url: url, title: title)));
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => PdfViewer(url: url, title: title)));
                }
              },
            );
          },
        );
      },
    );
  }
  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);
}
