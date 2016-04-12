
using Microsoft.AspNetCore.Mvc;
using System.Linq;

namespace RC2_WebApp_EF
{
    public class StudentsController : Controller
    {
   //     private StudentsContext _context;

   //     public StudentsController(StudentsContext context)
   //     {
   //         _context = context;
   //     }

   //     public IActionResult Index()
   //     {
   //         return View(_context.Students.ToList());
   //     }

   //     public IActionResult Create()
   //     {
   //         return View();
   //     }

   //     [HttpPost]
   //     [ValidateAntiForgeryToken]
   //     public IActionResult Create(Student st)
   //     {
   //         if (!ModelState.IsValid)
   //         {
			//	return View(st);
   //         }
            
			//try
			//{
			//	_context.Students.Add(st);
			//	_context.SaveChanges();
			//}
			//catch
			//{
			//	ModelState.AddModelError("", "Failed to create");
			//	return View(st);
			//}                
			//return RedirectToAction("Index");
   //     }

    }
}