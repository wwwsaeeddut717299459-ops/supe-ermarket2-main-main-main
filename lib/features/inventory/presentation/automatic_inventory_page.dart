import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/database_providers.dart';
import '../../../providers/currency_providers.dart';
import '../../../services/automatic_inventory_service.dart';
import '../../../services/currency_service.dart';

class AutomaticInventoryPage extends ConsumerStatefulWidget {
  const AutomaticInventoryPage({super.key});
  @override ConsumerState<AutomaticInventoryPage> createState() => _AutomaticInventoryPageState();
}

class _AutomaticInventoryPageState extends ConsumerState<AutomaticInventoryPage> {
  late DateTime _from, _to;
  late Future<InventoryAuditReport> _future;
  late final CurrencyService _currency;
  @override void initState() {
    super.initState();
    final n=DateTime.now(); _from=DateTime(n.year,n.month,n.day); _to=_from;
    _currency=ref.read(currencyServiceProvider); _future=_load();
  }
  Future<InventoryAuditReport> _load() async { await _currency.load(); return AutomaticInventoryService(ref.read(databaseProvider)).build(from:_from,to:_to); }
  void _refresh()=>setState(()=>_future=_load());
  Future<void> _pickRange() async {
    final r=await showDateRangePicker(context:context,firstDate:DateTime(2020),lastDate:DateTime.now().add(const Duration(days:365)),initialDateRange:DateTimeRange(start:_from,end:_to));
    if(r==null)return; setState((){_from=DateTime(r.start.year,r.start.month,r.start.day);_to=DateTime(r.end.year,r.end.month,r.end.day);_future=_load();});
  }
  String _money(double v)=>_currency.format(_currency.fromYer(v,currency:_currency.displayCurrency),currency:_currency.displayCurrency);
  String _date(DateTime d)=>'${d.year}/${d.month.toString().padLeft(2,'0')}/${d.day.toString().padLeft(2,'0')} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  @override Widget build(BuildContext context)=>FutureBuilder<InventoryAuditReport>(future:_future,builder:(context,s){
    if(s.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());
    if(s.hasError)return Center(child:Text('تعذر إنشاء الجرد: ${s.error}'));
    final r=s.data!,t=r.totals,cs=Theme.of(context).colorScheme;
    final cards=[('المبيعات',_money(t['sales']!),Icons.point_of_sale_rounded),('المشتريات',_money(t['purchases']!),Icons.shopping_cart_rounded),('مرتجعات المبيعات',_money(t['saleReturns']!),Icons.assignment_return_rounded),('مرتجعات المشتريات',_money(t['purchaseReturns']!),Icons.assignment_return_outlined),('المصروفات',_money(t['expenses']!),Icons.money_off_rounded),('تحصيل العملاء',_money(t['customerPayments']!),Icons.payments_rounded),('سداد الموردين',_money(t['supplierPayments']!),Icons.local_shipping_rounded),('مصروف الموظفين',_money(t['employeePayments']!),Icons.badge_rounded),('دخول المخزون','${t['stockIn']}',Icons.south_west_rounded),('خروج المخزون','${t['stockOut']}',Icons.north_east_rounded),('عدد الحركات','${r.count}',Icons.list_alt_rounded)];
    return Column(children:[Padding(padding:const EdgeInsets.fromLTRB(20,18,20,10),child:Row(children:[Icon(Icons.inventory_rounded,size:30,color:cs.primary),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('الجرد الآلي الشامل',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w800)),const Text('ملخص كامل ثم جميع الحركات والتفاصيل خلال الفترة المحددة.')])),OutlinedButton.icon(onPressed:_pickRange,icon:const Icon(Icons.date_range_rounded),label:Text('${_date(_from).split(' ').first} — ${_date(_to).split(' ').first}')),const SizedBox(width:8),IconButton(onPressed:_refresh,tooltip:'تحديث',icon:const Icon(Icons.refresh_rounded))])),Expanded(child:ListView(padding:const EdgeInsets.fromLTRB(20,8,20,24),children:[LayoutBuilder(builder:(c,b){final cols=b.maxWidth>=1250?4:b.maxWidth>=800?3:2;return GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:cards.length,gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:cols,mainAxisExtent:92,crossAxisSpacing:12,mainAxisSpacing:12),itemBuilder:(_,i){final x=cards[i];return Card(elevation:0,child:Padding(padding:const EdgeInsets.all(14),child:Row(children:[CircleAvatar(child:Icon(x.$3)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[Text(x.$1,maxLines:1,overflow:TextOverflow.ellipsis),const SizedBox(height:5),Text(x.$2,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:16))]))])));});}),const SizedBox(height:20),Card(elevation:0,child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Text('كل التفاصيل',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800)),const Spacer(),Text('${r.count} حركة')]),const SizedBox(height:12),if(r.items.isEmpty)const Padding(padding:EdgeInsets.all(30),child:Center(child:Text('لا توجد حركات خلال الفترة المحددة.'))) else ...r.items.asMap().entries.map((e)=>ExpansionTile(leading:CircleAvatar(radius:18,child:Text('${e.key+1}',style:const TextStyle(fontSize:11))),title:Row(children:[Expanded(child:Text(e.value.type,style:const TextStyle(fontWeight:FontWeight.w700))),Text(_money(e.value.amount),style:const TextStyle(fontWeight:FontWeight.w800))]),subtitle:Text('${_date(e.value.date)} • ${e.value.reference} • ${e.value.party}',maxLines:2,overflow:TextOverflow.ellipsis),childrenPadding:const EdgeInsets.fromLTRB(20,0,20,14),children:[Align(alignment:Alignment.centerRight,child:SelectableText(e.value.details.isEmpty?'لا توجد تفاصيل إضافية.':e.value.details))]))])))]))]);
  });
}
