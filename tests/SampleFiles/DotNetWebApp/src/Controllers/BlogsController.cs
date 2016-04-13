
using Microsoft.AspNetCore.Mvc;
using System.Linq;

namespace RC2_WebApp_EF
{
    public class BlogsController : Controller
    {
   //     private BlogsContext _context;

   //     public BlogsController(BlogsContext context)
   //     {
   //         _context = context;
   //     }

   //     public IActionResult Index()
   //     {
   //         return View(_context.Blogs.ToList());
   //     }

   //     public IActionResult Create()
   //     {
   //         return View();
   //     }

   //     [HttpPost]
   //     [ValidateAntiForgeryToken]
   //     public IActionResult Create(Blog blog)
   //     {
   //         if (!ModelState.IsValid)
   //         {
			//	return View(blog);
   //         }
            
			//try
			//{
			//	_context.Blogs.Add(blog);
			//	_context.SaveChanges();
			//}
			//catch
			//{
			//	ModelState.AddModelError("", "Failed to create");
			//	return View(blog);
			//}                
			//return RedirectToAction("Index");
   //     }

    }
}