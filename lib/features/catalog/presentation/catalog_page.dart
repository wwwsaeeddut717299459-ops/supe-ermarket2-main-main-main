import 'package:flutter/material.dart';

import '../../categories/presentation/categories_page.dart';
import '../../products/presentation/products_page.dart';

class CatalogPage extends StatelessWidget {
  const CatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المنتجات والتصنيفات'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'المنتجات'),
              Tab(text: 'التصنيفات'),
            ],
          ),
        ),
        body: const TabBarView(children: [ProductsPage(), CategoriesPage()]),
      ),
    );
  }
}
