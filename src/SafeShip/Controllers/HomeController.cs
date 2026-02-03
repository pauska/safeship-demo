using Microsoft.AspNetCore.Mvc;

namespace SafeShip.Controllers
{
    public class HomeController : Controller
    {
        public IActionResult Index() => RedirectToAction("Index", "Products");
    }
}
