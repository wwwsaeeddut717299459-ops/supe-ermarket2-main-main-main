import 'package:drift/drift.dart';
import '../database/app_database.dart';
import 'audit_service.dart';
import 'finance_service.dart';

class EmployeeRecord {
 final int id; final String name, phone, jobTitle, notes; final double salary; final DateTime hireDate; final bool isActive;
 const EmployeeRecord({required this.id,required this.name,required this.phone,required this.jobTitle,required this.notes,required this.salary,required this.hireDate,required this.isActive});
}
class EmployeeTransaction {
 final int id, employeeId; final String type, description, notes; final double amount; final DateTime date;
 const EmployeeTransaction({required this.id,required this.employeeId,required this.type,required this.description,required this.notes,required this.amount,required this.date});
}
class EmployeeService {
 final AppDatabase db; EmployeeService(this.db);
 Future<List<EmployeeRecord>> getAll({String query=''}) async { final q=query.trim(); final rows=await db.customSelect("SELECT * FROM employees WHERE (? = '' OR name LIKE ? OR phone LIKE ? OR job_title LIKE ?) ORDER BY is_active DESC,name COLLATE NOCASE",variables:[Variable.withString(q),Variable.withString('%$q%'),Variable.withString('%$q%'),Variable.withString('%$q%')]).get(); return rows.map(_e).toList(); }
 Future<EmployeeRecord?> getById(int id) async { final r=await db.customSelect('SELECT * FROM employees WHERE id=?',variables:[Variable.withInt(id)]).get(); return r.isEmpty?null:_e(r.first); }
 Future<void> add({required String name,String phone='',String jobTitle='',double salary=0,DateTime? hireDate,String notes=''}) async { if(name.trim().isEmpty)throw Exception('اسم الموظف مطلوب'); if(salary<0)throw Exception('الراتب غير صحيح'); final now=DateTime.now().toIso8601String(); await db.customStatement('INSERT INTO employees(name,phone,job_title,salary,hire_date,is_active,notes,created_at) VALUES(?,?,?,?,?,?,?,?)',[name.trim(),phone.trim(),jobTitle.trim(),salary,(hireDate??DateTime.now()).toIso8601String(),1,notes.trim(),now]); }
 Future<void> update(int id,{required String name,String phone='',String jobTitle='',double salary=0,required DateTime hireDate,bool isActive=true,String notes=''}) async { await db.customStatement('UPDATE employees SET name=?,phone=?,job_title=?,salary=?,hire_date=?,is_active=?,notes=? WHERE id=?',[name.trim(),phone.trim(),jobTitle.trim(),salary,hireDate.toIso8601String(),isActive?1:0,notes.trim(),id]); }
 Future<void> setActive(int id,bool active)=>db.customStatement('UPDATE employees SET is_active=? WHERE id=?',[active?1:0,id]);
 Future<List<EmployeeTransaction>> transactions(int id) async { final rows=await db.customSelect('SELECT * FROM employee_transactions WHERE employee_id=? ORDER BY transaction_date DESC,id DESC',variables:[Variable.withInt(id)]).get(); return rows.map(_t).toList(); }
 Future<void> addTransaction({required int employeeId,required String type,required double amount,required DateTime date,String description='',String notes='',String username='النظام'}) async { if(amount<=0)throw Exception('المبلغ يجب أن يكون أكبر من صفر'); final e=await getById(employeeId); if(e==null)throw Exception('الموظف غير موجود'); await db.customStatement('INSERT INTO employee_transactions(employee_id,type,amount,transaction_date,description,notes,created_at) VALUES(?,?,?,?,?,?,?)',[employeeId,type,amount,date.toIso8601String(),description.trim(),notes.trim(),DateTime.now().toIso8601String()]);
    // دمج الحركة مع المصروفات والحسابات حتى تدخل التقارير وصافي الربح.
    final categories = await db.expenseCategoriesDao.getAll();
    ExpenseCategory? category;
    for (final x in categories) { if (x.name.trim() == 'مصروفات الموظفين') { category = x; break; } }
    if (category == null) {
      await db.expenseCategoriesDao.insertCategory(ExpenseCategoriesCompanion.insert(name: 'مصروفات الموظفين'));
      final refreshed = await db.expenseCategoriesDao.getAll();
      category = refreshed.where((x) => x.name.trim() == 'مصروفات الموظفين').first;
    }
    await ExpenseService(db).addExpense(categoryId: category.id, amount: amount, paymentMethod: 'cash', date: date, description: '${_tn(type)} • ${e.name}${description.trim().isEmpty ? '' : ' • ${description.trim()}'}');
    await AuditService().log(user:username,action:'عملية موظف',details:'${_tn(type)} • ${e.name} • المبلغ: $amount • ${description.trim()}'); }
 static String _tn(String t)=>switch(t){'salary'=>'راتب','advance'=>'سلفة','withdrawal'=>'سحب','payment'=>'صرف',_=>'حركة'};
 static EmployeeRecord _e(QueryRow r)=>EmployeeRecord(id:r.read<int>('id'),name:r.read<String>('name'),phone:r.read<String>('phone'),jobTitle:r.read<String>('job_title'),notes:r.read<String>('notes'),salary:r.read<double>('salary'),hireDate:DateTime.tryParse(r.read<String>('hire_date'))??DateTime.now(),isActive:r.read<int>('is_active')==1);
 static EmployeeTransaction _t(QueryRow r)=>EmployeeTransaction(id:r.read<int>('id'),employeeId:r.read<int>('employee_id'),type:r.read<String>('type'),amount:r.read<double>('amount'),date:DateTime.tryParse(r.read<String>('transaction_date'))??DateTime.now(),description:r.read<String>('description'),notes:r.read<String>('notes'));
}
