using Microsoft.EntityFrameworkCore;
using System.ComponentModel.DataAnnotations;

namespace RC2_WebApp_EF
{
    public class BlogsContext : DbContext
    {
		public BlogsContext(DbContextOptions options)
		    :base(options)
		{}
		
        public DbSet<Blog> Blogs { get; set; }
      
	    protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
		}
    }

     public class Blog
    {
		[Required]
        public int Id { get; set; }
		[Required]
		[StringLength(100)]
        public string Url { get; set; }

    }
}

